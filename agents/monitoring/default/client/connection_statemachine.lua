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
local hsm = require('hsm')
local logging = require('logging')
local fmt = require('string').format

--[[
  Respawn emits a 'respawn' event.

  If the statemachine receives a state = done event, it will transition to the
  'Deactivate' state. This is to allow the case where we have error cases or 'end'
  events on the socket.

  The react callbacks include an optional 'state' parameter to potentially
  effect the transitions.
]]--

local ConnectionStateMachine = hsm.StateMachine:extend()
function ConnectionStateMachine:initialize(connectionStream)
  self._connectionStream = connectionStream
  self._emittedRespawn = false
  self:defineStates({
    Default = {},
    Handshake = {},
    Deactivate = {},
    TimeSync = {},
    TimeSyncDeactivate = {},
    Respawn = {},
    Running = {},
    Done = {}
  })
  self.state = self.states.Default
end

function ConnectionStateMachine:_autoTransition(client, state, msg)
  process.nextTick(function()
    self:react(client, state, msg)
  end)
end

function ConnectionStateMachine:_reactDefault(client, state, msg)
  client:log(logging.DEBUG, fmt('machine: state=Default (%s)', state or 'none'))
  if state and state =='connect' then
    return self.states.Handshake
  end
  if state and state == 'done' then
    self:_autoTransition(client, state, msg)
    return self.states.Deactivate
  end
  return self.states.Default
end

function ConnectionStateMachine:_reactHandshake(client, state, msg)
  client:log(logging.DEBUG, fmt('machine: state=Handshake (%s)', state or 'none'))
  if state and state == 'done' then
    self:_autoTransition(client, state, msg)
    return self.states.Deactivate
  end
  self._connectionStream:promoteClient(client)
  self._connectionStream:clearDelay(client.datacenter)
  --self._connectionStream:getUpgrade():start()
  client:startHeartbeatInterval()
  return self.states.TimeSync
end

function ConnectionStateMachine:_reactTimeSync(client, state, msg)
  client:log(logging.DEBUG, fmt('machine: state=TimeSync (%s)', state or 'none'))
  if state and state == 'done' then
    self:_autoTransition(client, state, msg)
    return self.states.Deactivate
  end
  if not self._connectionStream:isTimeSyncActive() then
    self._connectionStream:setActiveTimeSyncClient(client)
  end
  return self.states.Running
end

function ConnectionStateMachine:_reactRunning(client, state, msg)
  client:log(logging.DEBUG, fmt('machine: state=Running (%s)', state or 'none'))
  if state == 'done' then
    self:_autoTransition(client, state, msg)
    return self.states.Deactivate
  end
  return self.states.Running
end

function ConnectionStateMachine:_reactDeactivate(client, state, msg)
  client:log(logging.DEBUG, fmt('machine: state=Deactivate (%s)', state or 'none'))
  if state == 'done' then
    self:_autoTransition(client, state, msg)
    return self.states.TimeSyncDeactivate
  end
  client:clearHeartbeatInterval()
  if self._connectionStream:getClient() == nil then
    self._connectionStream:getUpgrade():stop()
  end
  self:_autoTransition(client, state, msg)
  return self.states.TimeSyncDeactivate
end

function ConnectionStateMachine:_reactTimeSyncDeactivate(client, state, msg)
  client:log(logging.DEBUG, fmt('machine: state=TimeSyncDeactivate (%s)', state or 'none'))
  if state == 'done' then
    self:_autoTransition(client, state, msg)
    return self.states.Respawn
  end
  if client == self._connectionStream:getActiveTimeSyncClient() then
    local newClient = self._connectionStream:getClient()
    self._connectionStream:setActiveTimeSyncClient(newClient)
  end
  self:_autoTransition(client, state, msg)
  return self.states.Respawn
end

function ConnectionStateMachine:_reactRespawn(client, state, msg)
  client:log(logging.DEBUG, 'machine: state=Respawn')
  self:emit('respawn')
  return self.states.Done
end

function ConnectionStateMachine:_reactDone(client, state, msg)
  client:log(logging.DEBUG, 'machine: state=Done')
  return self.states.Done
end

local exports = {}
exports.ConnectionStateMachine = ConnectionStateMachine
return exports
