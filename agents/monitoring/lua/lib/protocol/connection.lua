local JSON = require('json')
local Emitter = require('core').Emitter
local utils = require('utils')
local table = require('table')
local msg = require ('./messages')
local AgentProtocol = require('./protocol')

local logging = require('logging')
local fmt = require('string').format

local AgentProtocolConnection = Emitter:extend()

local COMPLETION_TIMEOUT = 30

local STATES = {}
STATES.INITIAL = 1
STATES.HANDSHAKE = 2
STATES.RUNNING = 3

function AgentProtocolConnection:_onData(data)
  local client = self._conn, obj
  newline = data:find("\n")
  if newline then
    -- TODO: use a better buffer
    self._buf = self._buf .. data:sub(1, newline - 1)
    logging.log(logging.DEBUG, fmt("RECV:%s", self._buf))
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
  else
    -- response
    local key = msg.source .. ':' .. msg.id
    local cpl = self._completions[key]
    if cpl then
      self._completions[key] = nil
      cpl(null, msg)
    end
  end
end

function AgentProtocolConnection:_send(msg, timeout, callback)
  msg.target = 'endpoint'
  msg.source = self._myid
  local data = JSON.stringify(msg) .. '\n'
  logging.log(logging.DEBUG, fmt("SEND:%s", JSON.stringify(msg)))
  if timeout and callback then
    self._completions[msg.target .. ':' .. msg.id] = callback
  end
  self._conn:write(data)
  self._msgid = self._msgid + 1
end

function AgentProtocolConnection:sendHandshakeHello(agentId, token, callback)
  local m = msg.HandshakeHello:new(token, agentId)
  self:_send(m:serialize(self._msgid), COMPLETION_TIMEOUT, callback)
end

function AgentProtocolConnection:setState(state)
  self._state = state
end

function AgentProtocolConnection:startHandshake()
  self:setState(STATES.HANDSHAKE)
  self:sendHandshakeHello(self._myid, self._token, function(err, msg)
    if err then
      logging.log(logging.ERR, fmt("handshake failed (message=%s)", err.message))
      return
    end
    if msg.result ~= nil and msg.result.code ~= 200 then
      logging.log(logging.ERR, fmt("handshake failed [message=%s,code=%s]", msg.result.message, msg.result.code))
      return
    end
    self:setState(STATES.RUNNING)
    logging.log(logging.INFO, "handshake successful")
  end)
end

function AgentProtocolConnection:initialize(myid, token, conn)
  assert(conn ~= nil)
  assert(myid ~= nil)
  self._myid = myid
  self._token = token
  self._conn = conn
  self._conn:on('data', utils.bind(AgentProtocolConnection._onData, self))
  self._buf = ""
  self._msgid = 0
  self._endpoints = { }
  self._target = 'endpoint'
  self._completions = {}
  self:setState(STATES.INITIAL)
end

return AgentProtocolConnection
