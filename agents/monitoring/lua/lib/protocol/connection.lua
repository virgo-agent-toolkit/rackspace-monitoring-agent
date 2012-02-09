local JSON = require('json')
local Emitter = require('core').Emitter
local utils = require('utils')
local table = require('table')
local msg = require ('./messages')
local AgentProtocol = require('./protocol')

local logging = require('logging')
local fmt = require('string').format

local AgentProtocolConnection = Emitter:extend()

function AgentProtocolConnection:_onData(data)
  local client = self._conn, obj
  newline = data:find("\n")
  if newline then
    -- TODO: use a better buffer
    self._buf = self._buf .. data:sub(1, newline - 1)
    logging.log(logging.DEBUG, fmt("MSG:%s", self._buf))
    obj = JSON.parse(self._buf)
    self:_processMessage(obj)
    self._buf = data:sub(newline + 1)
  else
    self._buf = self._buf .. data
  end
end

function AgentProtocolConnection:_processMessage(msg)
  -- request
  if msg.method ~= nil then
    self:emit('message', msg)
  elseif msg.result ~= nil then
    -- response
    local key = msg.source .. ':' .. msg.id
    local cpl = self._completions[key]
    if cpl then
      self._completions[key] = nil
      cpl(null, msg)
    end
  else
    -- TODO error
  end
end

function AgentProtocolConnection:_send(msg, timeout, callback)
  msg.target = 'endpoint'
  msg.source = self._myid
  local data = JSON.stringify(msg) .. '\n'
  if timeout and callback then
    self._completions[msg.target .. ':' .. msg.id] = callback
  end
  self._conn:write(data)
  self._msgid = self._msgid + 1
end

function AgentProtocolConnection:sendHandshakeHello(agentId, token, options, callback)
  local m = msg.HandshakeHello:new(self._myid, agentId)
  self:_send(m:serialize(self._msgid), 30, callback)
end

function AgentProtocolConnection:initialize(myid, conn)
  assert(conn ~= nil)
  assert(myid ~= nil)
  self._myid = myid
  self._conn = conn
  self._conn:on('data', utils.bind(AgentProtocolConnection._onData, self))
  self._buf = ""
  self._msgid = 0
  self._endpoints = { }
  self._target = 'endpoint'
  self._completions = {}
end

return AgentProtocolConnection
