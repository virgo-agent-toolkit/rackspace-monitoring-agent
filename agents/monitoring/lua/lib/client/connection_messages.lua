local bind = require('utils').bind
local timer = require('timer')
local Emitter = require('core').Emitter
local Object = require('core').Object
local misc = require('../util/misc')
local logging = require('logging')
local loggingUtil = require ('../util/logging')
local table = require('table')
local os = require('os')
local Scheduler = require('../schedule').Scheduler

local fmt = require('string').format

function SECONDS(n, jitter)
  return misc.calcJitter(n * 1000, jitter * 1000)
end

-- State

local State = Emitter:extend()

function State:initialize(name, messages)
  self._name = name
  self._messages = messages
  self._log = loggingUtil.makeLogger(fmt('State(%s)', self._name))
end

function State:getName()
  return self._name
end

-- RegisterCheckState State

local RegisterCheckState = State:extend()
function RegisterCheckState:initialize(messages)
  State.initialize(self, 'RegisterCheckState', messages)
  self._timeout = SECONDS(20, 10)
  self._lastFetchTime = 0
end

function RegisterCheckState:_scheduleManifest(client, manifest)
  local checks = client:_createChecks(manifest)
  self._scheduler = Scheduler:new('scheduler.state', checks, function()
    self._scheduler:start()
  end)
  self._scheduler:on('check', function(check, checkResults)
    local client = self._messages:getStream():getClient()
    if client then
      client.protocol:sendMetrics(check, checkResults)
    end
  end)
end

function RegisterCheckState:onHandshake()

  function run()
    local client = self._messages:getStream():getClient()
    if client then
      client.protocol:getManifest(function(err, manifest)
        if err then
          -- TODO Abort connection?
          client:getLog()(logging.ERROR, 'Error while retrieving manifest: ' .. err.message)
        else
          self:_scheduleManifest(client, manifest)
        end
      end)
    end
  end

  -- TODO at some point we want to add logic to update the manifest
  if self._lastFetchTime == 0 then
    if self._timer then
      timer.clearTimer(self._timer)
    end
    self._log(logging.DEBUG, fmt('registering timeout %d', self._timeout))
    self._timer = process.nextTick(run)
    self._lastFetchTime = os.time()
  end
end

-- Connection Messages

local ConnectionMessages = Emitter:extend()
function ConnectionMessages:initialize(connectionStream)
  self._connectionStream = connectionStream
  self._states = {}
  self:_addState(RegisterCheckState:new(self))
  self:on('handshake_success', bind(ConnectionMessages.onHandshake, self))
  self:on('client_end', bind(ConnectionMessages.onClientEnd, self))
  self:on('message', bind(ConnectionMessages.onMessage, self))
end

function ConnectionMessages:_addState(state)
  table.insert(self._states, state)
end

function ConnectionMessages:getStream()
  return self._connectionStream
end

function ConnectionMessages:onClientEnd(client)
  client:getLog()(logging.INFO, 'Detected client disconnect')
  for i in ipairs(self._states) do
    if self._states[i].onClientEnd then
      self._states[i]:onClientEnd(client)
    end
  end
end

function ConnectionMessages:onHandshake(client)
  client:getLog()(logging.DEBUG, '(onHandshake)')
  for i in ipairs(self._states) do
    if self._states[i].onHandshake then
      self._states[i]:onHandshake(client)
    end
  end
end

function ConnectionMessages:onMessage(client, msg)
  client:getLog()(logging.DEBUG, '(onMessage)')
  for i in ipairs(self._states) do
    if self._states[i].onMessage then
      self._states[i]:onMessage(client, msg)
    end
  end
  client.protocol:processMessage(msg)
end

local exports = {}
exports.State = State
exports.ConnectionMessages = ConnectionMessages
return exports
