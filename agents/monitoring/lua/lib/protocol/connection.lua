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

--[[ Request Functions ]]--
local requests = {}

requests['handshake.hello'] = function(agentId, token, callback)
  local m = msg.HandshakeHello:new(token, agentId)
  self:_send(m:serialize(self._msgid), HANDSHAKE_TIMEOUT, 200, callback)
end

requests['heartbeat.ping'] = function(timestamp, callback)
  local m = msg.Ping:new(timestamp)
  self:_send(m:serialize(self._msgid), nil, 200, callback)
end

requests['manifest.get'] = function(callback)
  local m = msg.Manifest:new()
  self:_send(m:serialize(self._msgid), nil, 200, callback)
end

requests['metrics.set'] = function(check, checkResults, callback)
  local m = msg.MetricsRequest:new(check, checkResults)
  self:_send(m:serialize(self._msgid), nil, 200, callback)
end

--[[ Reponse Functions ]]--
local responses = {}

responses['check.schedule_changed'] = function(replyTo, callback)
  local m = msg.ScheduleChangeAck:new(replyTo)
  self:_send(m:serialize(self._msgid), nil, 200)
  callback()
end

responses['system.info'] = function(request, callback)
  local m = msg.SystemInfoResponse:new(request)
  self:_send(m:serialize(self._msgid), nil, 200, callback)
end


function AgentProtocolConnection:initialize(log, myid, token, conn)
  assert(conn ~= nil)
  assert(myid ~= nil)

  self._log = log
  self._myid = myid
  self._token = token
  self._conn = conn
  self._conn:on('data', utils.bind(AgentProtocolConnection._onData, self))
  self._buf = ''
  self._msgid = 0
  self._endpoints = { }
  self._target = 'endpoint'
  self._timeoutIds = {}
  self._completions = {}
  self._requests = {}
  self._responses = {}
  self:setState(STATES.INITIAL)
end

function AgentProtocolConnection:request(name, ...)
  return self._requests[name](unpack(arg))
end

function AgentProtocolConnection:respond(name, ...)
  return self._responses[name](unpack(arg))
end

function AgentProtocolConnection:_popLine()
  local line = false
  local index = self._buf:find('\n')

  if index then
    line = self._buf:sub(0, index - 1)
    self._buf = self._buf:sub(index + 1)
  end

  return line
end

function AgentProtocolConnection:_onData(data)
  local obj, status, line

  self._buf = self._buf .. data

  line = self:_popLine()
  while line do
    status, obj = pcall(JSON.parse, line)

    if not status then
      self._log(logging.ERROR, fmt('Failed to parse incoming line: line="%s",err=%s', line, obj))
    else
      self:_processMessage(obj)
    end

    line = self:_popLine()
  end
end

function AgentProtocolConnection:_processMessage(msg)
  -- request
  if msg.method ~= nil then
    self:emit('message', msg)
  else
    -- response
    local key = self:_completionKey(msg.source, msg.id)
    local callback = self._completions[key]
    if callback then
      self._completions[key] = nil
      callback(null, msg)
    end
  end
end

--[[
Generate the completion key for a given message id and source (optional)

arg[1] - source or msgid
arg[2] - msgid if source provided
]]--
function AgentProtocolConnection:_completionKey(...)
  local args = {...}
  local msgid = nil
  local source = nil

  if #args == 1 then
    source = self._myid
    msgid = args[1]
  elseif #args == 2 then
    source = args[1]
    msgid = args[2]
  else
    return nil
  end

  return source .. ':' .. msgid
end

function AgentProtocolConnection:_send(msg, timeout, expectedCode, callback)
  msg.target = 'endpoint'
  msg.source = self._myid
  local msg_str = JSON.stringify(msg)
  local data = msg_str .. '\n'
  local key = self:_completionKey(msg.target, msg.id)

  self._log(logging.DEBUG, fmt('SEND: %s', msg_str))

  if not expectedCode then expectedCode = 200 end

  if timeout then
    self:_setCommandTimeoutHandler(key, timeout, callback)
  end

  if callback then
    self._completions[key] = function(err, msg)
      local result = nil

      if msg and msg.result then result = msg.result end

      if self._timeoutIds[key] ~= nil then
        timer.clearTimer(self._timeoutIds[key])
      end

      if not err and msg and result and result.code and result.code ~= expectedCode then
        err = Error:new(fmt('Unexpected status code returned: code=%s, message=%s', result.code, result.message))
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

--[[ Public Functions ]] --

function AgentProtocolConnection:setState(state)
  self._state = state
end

function AgentProtocolConnection:startHandshake(callback)
  self:setState(STATES.HANDSHAKE)
  self:request('handshake.hello', self._myid, self._token, function(err, msg)
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

function AgentProtocolConnection:getManifest(callback)
  self:request('manifest.get', (function(err, response)
    if err then
      callback(err)
    else
      callback(nil, response.result)
    end
  end)
end

--[[
Process an async message

msg - The Incoming Message
]]--
function AgentProtocolConnection:execute(msg)
  if msg.method == 'system.info' then
    self:respond('system.info', msg)
  else
    local err = Error:new(fmt('invalid method [method=%s]', msg.method))
    self:emit('error', err)
  end
end


return AgentProtocolConnection
