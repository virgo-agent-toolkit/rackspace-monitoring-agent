--[[
Copyright 2012 Rackspace

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]

local os = require('os')
local timer = require('timer')
local AgentProtocol = require('./protocol')
local Emitter = require('core').Emitter
local Error = require('core').Error
local JSON = require('json')
local fmt = require('string').format
local logging = require('logging')
local msg = require ('./messages')
local table = require('table')
local utils = require('utils')

-- Response timeouts in ms
local HANDSHAKE_TIMEOUT = 30000

local STATES = {}
STATES.INITIAL = 1
STATES.HANDSHAKE = 2
STATES.RUNNING = 3

local AgentProtocolConnection = Emitter:extend()

function AgentProtocolConnection:initialize(log, myid, token, conn)
  assert(conn ~= nil)
  assert(myid ~= nil)

  self._log = log
  self._myid = myid
  self._token = token
  self._conn = conn
  self._conn:on('data', utils.bind(AgentProtocolConnection._onData, self))
  self._buf = ""
  self._msgid = 0
  self._endpoints = { }
  self._target = 'endpoint'
  self._timeoutIds = {}
  self._completions = {}
  self:setState(STATES.INITIAL)
end

function AgentProtocolConnection:_onData(data)
  local client = self._conn, obj
  newline = data:find("\n")
  if newline then
    -- TODO: use a better buffer
    self._buf = self._buf .. data:sub(1, newline - 1)
    self._log(logging.DEBUG, fmt('RECV: %s', self._buf))
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
  local key = msg.target .. ':' .. msg.id
  self._log(logging.DEBUG, fmt('SEND: %s', data))

  if timeout then
    self:_setCommandTimeoutHandler(key, timeout, callback)
  end

  if callback then
    self._completions[key] = function(err, msg)
      if self._timeoutIds[key] ~= nil then
        timer.clearTimer(self._timeoutIds[key])
      end

      callback(err, msg)
    end
  end

  self._conn:write(data)
  self._msgid = self._msgid + 1
end

--[[
Set a timeout handler for a function.

key - Command key.
timeout - Timeout in ms.
callback - Callback which is called with (err) if timeout has been reached.
]]--
function AgentProtocolConnection:_setCommandTimeoutHandler(key, timeout, callback)
  local timeoutId

  timeoutId = timer.setTimeout(timeout, function()
    callback(Error:new(fmt('Command timeout, haven\'t received response in %d ms', timeout)))
  end)
  self._timeoutIds[key] = timeoutId
end

function AgentProtocolConnection:sendHandshakeHello(agentId, token, callback)
  local m = msg.HandshakeHello:new(token, agentId)
  self:_send(m:serialize(self._msgid), HANDSHAKE_TIMEOUT, callback)
end

function AgentProtocolConnection:sendPing(timestamp, callback)
  local m = msg.Ping:new(timestamp)
  self:_send(m:serialize(self._msgid), nil, callback)
end

function AgentProtocolConnection:setState(state)
  self._state = state
end

function AgentProtocolConnection:startHandshake(callback)
  self:setState(STATES.HANDSHAKE)
  self:sendHandshakeHello(self._myid, self._token, function(err, msg)
    if err then
      self._log(logging.ERR, fmt('handshake failed (message=%s)', err.message))
      callback(err, msg)
      return
    end

    if msg.result.code and msg.result.code ~= 200 then
      err = Error:new(fmt('handshake failed [message=%s,code=%s]', msg.result.message, msg.result.code))
      self._log(logging.ERR, err.message)
      callback(err, msg)
      return
    end

    self:setState(STATES.RUNNING)
    self._log(logging.INFO, fmt('handshake successful (ping_interval=%dms)', msg.result.ping_interval))
    callback(nil, msg)
  end)
end

return AgentProtocolConnection
