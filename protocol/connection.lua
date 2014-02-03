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
local Emitter = require('core').Emitter
local Error = require('core').Error
local errors = require('./errors')
local ResponseTimeoutError = require('../errors').ResponseTimeoutError
local JSON = require('json')
local fmt = require('string').format
local http = require('http')

local logging = require('logging')
local msg = require ('./messages')
local table = require('table')
local utils = require('utils')
local hostInfo = require('../host_info')
local check = require('../check')
local misc = require('../util/misc')
local vutils = require('virgo_utils')

-- Response timeouts in ms
local HANDSHAKE_TIMEOUT = 30000

local STATES = {}
STATES.INITIAL = 1
STATES.HANDSHAKE = 2
STATES.RUNNING = 3

local AgentProtocolConnection = Emitter:extend()

--[[ Request Functions ]]--
local requests = {}

requests['handshake.hello'] = function(self, agentId, token, callback)
  local m = msg.HandshakeHello:new(token, agentId)
  self:_send(m, callback, self.HANDSHAKE_TIMEOUT)
end

requests['heartbeat.post'] = function(self, timestamp, callback)
  local m = msg.Heartbeat:new(timestamp)
  self:_send(m, callback)
end

requests['binary_upgrade.get_version'] = function(self, callback)
  local m = msg.BinaryUpgradeRequest:new()
  self:_send(m, callback)
end

requests['bundle_upgrade.get_version'] = function(self, callback)
  local m = msg.BundleUpgradeRequest:new()
  self:_send(m, callback)
end

requests['db.checks.create'] = function(self, params, callback)
  local m = msg.db.checks.create:new(params)
  self:_send(m, callback)
end

requests['db.checks.list'] = function(self, params, paginationParams, callback)
  local m = msg.db.checks.list:new(params, paginationParams)
  self:_send(m, callback)
end

requests['db.checks.get'] = function(self, entityId, checkId, callback)
  local m = msg.db.checks.get:new(entityId, checkId)
  self:_send(m, callback)
end

requests['db.checks.remove'] = function(self, entityId, checkId, callback)
  local m = msg.db.checks.remove:new(entityId, checkId)
  self:_send(m, callback)
end

requests['db.checks.update'] = function(self, entityId, checkId, params, callback)
  local m = msg.db.checks.update:new(entityId, checkId, params)
  self:_send(m, callback)
end

requests['db.alarms.list'] = function(self, entityId, paginationParams, callback)
  local m = msg.db.alarms.list:new(entityId, paginationParams)
  self:_send(m, callback)
end

requests['db.alarms.get'] = function(self, entityId, alarmId, callback)
  local m = msg.db.alarms.get:new(entityId, alarmId)
  self:_send(m, callback)
end

requests['db.alarms.create'] = function(self, entityId, params, callback)
  local m = msg.db.alarms.create:new(entityId, params)
  self:_send(m, callback)
end

requests['db.alarms.remove'] = function(self, entityId, alarmId, callback)
  local m = msg.db.alarms.remove:new(entityId, alarmId)
  self:_send(m, callback)
end

requests['db.alarms.update'] = function(self, entityId, alarmId, params, callback)
  local m = msg.db.alarms.update:new(entityId, alarmId, params)
  self:_send(m, callback)
end

requests['db.notification.get'] = function(self, notificationId, callback)
  local m = msg.db.notification.get:new(notificationId)
  self:_send(m, callback)
end

requests['db.notification.list'] = function(self, paginationParams, callback)
  local m = msg.db.notification.list:new(paginationParams)
  self:_send(m, callback)
end

requests['db.notification.create'] = function(self, params, callback)
  local m = msg.db.notification.create:new(params)
  self:_send(m, callback)
end

requests['db.notification.remove'] = function(self, notificationId, callback)
  local m = msg.db.notification.remove:new(notificationId, alarmId)
  self:_send(m, callback)
end

requests['db.notification.update'] = function(self, notificationId, params, callback)
  local m = msg.db.notification.update:new(notificationId, params)
  self:_send(m, callback)
end

requests['db.notification_plan.get'] = function(self, notificationId, callback)
  local m = msg.db.notification_plan.get:new(notificationId)
  self:_send(m, callback)
end

requests['db.notification_plan.list'] = function(self, paginationParams, callback)
  local m = msg.db.notification_plan.list:new(paginationParams)
  self:_send(m, callback)
end

requests['db.notification_plan.create'] = function(self, params, callback)
  local m = msg.db.notification_plan.create:new(params)
  self:_send(m, callback)
end

requests['db.notification_plan.remove'] = function(self, notificationId, callback)
  local m = msg.db.notification_plan.remove:new(notificationId, alarmId)
  self:_send(m, callback)
end

requests['db.notification_plan.update'] = function(self, notificationId, params, callback)
  local m = msg.db.notification_plan.update:new(notificationId, params)
  self:_send(m, callback)
end

--[[ Reponse Functions ]]--
local responses = {}

responses['binary_upgrade.available'] = function(self, replyTo, callback)
  local m = msg.Response:new(replyTo)
  self:_send(m, callback)
end

responses['bundle_upgrade.available'] = function(self, replyTo, callback)
  local m = msg.Response:new(replyTo)
  self:_send(m, callback)
end

function AgentProtocolConnection:initialize(log, myid, token, guid, conn)

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
  self._requests = requests
  self._responses = responses
  self._guid = guid
  self.HANDSHAKE_TIMEOUT = HANDSHAKE_TIMEOUT
  self:setState(STATES.INITIAL)
end

function AgentProtocolConnection:request(name, ...)
  local t = {...}
  return self._requests[name](self, unpack(t,1,table.maxn(t)))
end

function AgentProtocolConnection:respond(name, ...)
  local args = {...}
  local callback = args[#args]
  local method = self._responses[name]

  if type(callback) ~= 'function' then
    error('last argument to respond() must be a callback')
  end

  if method == nil then
    local err = errors.InvalidMethodError:new(name)
    callback(err)
    return
  else
    return method(self, unpack(args))
  end
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
    self._log(logging.DEBUG, 'got line: ' .. line)

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
    else
      self._log(logging.ERROR, fmt('Ignoring unexpected response object %s', key))
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
    source = self._guid
    msgid = args[1]
  elseif #args == 2 then
    source = args[1]
    msgid = args[2]
  else
    return nil
  end

  return source .. ':' .. msgid
end

function AgentProtocolConnection:_send(msg, callback, timeout)
  msg = msg:serialize(self._msgid)

  msg.target = 'endpoint'
  msg.source = self._guid
  local msg_str = JSON.stringify(msg)
  local data = msg_str .. '\n'
  local key = self:_completionKey(msg.target, msg.id)

  if timeout then
    self:_setCommandTimeoutHandler(key, timeout, callback)
  end

  -- if the msg does not have a method then it is
  -- a response so we don't expect a reply. Don't
  -- create a completion in this case.
  if (msg.method == nil) then
    if callback then callback() end
  else
    self._completions[key] = function(err, resp)
      local result = nil

      if self._timeoutIds[key] ~= nil then
        timer.clearTimer(self._timeoutIds[key])
      end

      if not err and resp then
        local resp_err = resp['error']

        -- response version must match request version
        if resp.v ~= msg.v then
          err = errors.VersionError:new(msg, resp)
        -- emit error if error field is set
        elseif resp_err then
          err = errors.ProtocolError:new(resp_err)
        end

        if err then
          -- All 400 errors will be logged, but not re-emitted. All other errors
          -- will cause the connection to be dropped to the endpoint. We may
          -- need to revise this behavior in the future.
          if err.code == 400 then
            self._log(logging.ERROR, fmt('Non-fatal error: %s', err.message))
          else
            self:emit('error', err)
          end
        end
      end

      if callback then
        callback(err, resp)
      end
    end
  end

  self._log(logging.DEBUG, fmt('SENDING: (%s) => %s', key, data))
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
    local msg = fmt("Command timeout, haven't received response in %d ms", timeout)
    local err = ResponseTimeoutError:new(msg)
    callback(err)
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
      return callback(err, msg)
    end

    self:setState(STATES.RUNNING)
    self._log(logging.DEBUG, fmt('handshake successful (heartbeat_interval=%dms)', msg.result.heartbeat_interval))
    callback(nil, msg)
  end)
end

--[[ db.Checks ]]

function AgentProtocolConnection:dbCreateChecks(entityId, params, callback)
  local p = misc.merge(params, { entity_id = entityId })
  self:request('db.checks.create', p, callback)
end

function AgentProtocolConnection:dbListChecks(params, paginationParams, callback)
  self:request('db.checks.list', params, paginationParams, callback)
end

function AgentProtocolConnection:dbGetChecks(entityId, checkId, callback)
  self:request('db.checks.get', entityId, checkId, callback)
end

function AgentProtocolConnection:dbRemoveChecks(entityId, checkId, callback)
  self:request('db.checks.remove', entityId, checkId, callback)
end

function AgentProtocolConnection:dbUpdateChecks(entityId, checkId, params, callback)
  self:request('db.checks.update', entityId, checkId, params, callback)
end

--[[ db.Alarms ]]

function AgentProtocolConnection:dbListAlarms(entityId, paginationParams, callback)
  self:request('db.alarms.list', entityId, paginationParams, callback)
end

function AgentProtocolConnection:dbGetAlarms(entityId, alarmId, callback)
  self:request('db.alarms.get', entityId, alarmId, callback)
end

function AgentProtocolConnection:dbCreateAlarms(entityId, params, callback)
  local p = misc.merge(params, { entity_id = entityId })
  self:request('db.alarms.create', p, callback)
end

function AgentProtocolConnection:dbRemoveAlarms(entityId, alarmId, callback)
  self:request('db.alarms.remove', entityId, alarmId, callback)
end

function AgentProtocolConnection:dbUpdateAlarms(entityId, alarmId, params, callback)
  self:request('db.alarms.update', entityId, alarmId, params, callback)
end

--[[ db.Notification --]]

function AgentProtocolConnection:dbGetNotification(notificationId, callback)
  self:request('db.notification.get', notificationId, callback)
end

function AgentProtocolConnection:dbCreateNotification(params, callback)
  self:request('db.notification.create', params, callback)
end

function AgentProtocolConnection:dbListNotification(paginationParams, callback)
  self:request('db.notification.list', paginationParams, callback)
end

function AgentProtocolConnection:dbRemoveNotification(notificationId, callback)
  self:request('db.notification.remove', notificationId, callback)
end

function AgentProtocolConnection:dbUpdateNotification(notificationId, params, callback)
  self:request('db.notification.update', notificationId, params, callback)
end

--[[ db.NotificationPlan --]] 
function AgentProtocolConnection:dbGetNotificationPlan(notificationId, callback)
  self:request('db.notification_plan.get', notificationId, callback)
end

function AgentProtocolConnection:dbCreateNotificationPlan(params, callback)
  self:request('db.notification_plan.create', params, callback)
end

function AgentProtocolConnection:dbListNotificationPlan(paginationParams, callback)
  self:request('db.notification_plan.list', paginationParams, callback)
end

function AgentProtocolConnection:dbRemoveNotificationPlan(notificationId, callback)
  self:request('db.notification_plan.remove', notificationId, callback)
end

function AgentProtocolConnection:dbUpdateNotificationPlan(notificationId, params, callback)
  self:request('db.notification_plan.update', notificationId, params, callback)
end

return AgentProtocolConnection
