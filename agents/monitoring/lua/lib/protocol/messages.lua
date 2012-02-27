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

local Object = require('core').Object

--[[ Message ]]--

local Message = Object:extend()
function Message:initialize()
  self.id = '1'
  self.target = ''
  self.source = ''
end

--[[ Request ]]--

local Request = Message:extend()

function Request:initialize()
  Message.initialize(self)
  self.method = ''
  self.params = {}
end

function Request:serialize(msgId)
  self.id = msgId

  return {
    v = '1',
    id = self.id,
    target = self.target,
    source = self.source,
    method = self.method,
    params = self.params
  }
end

--[[ Handshake.Hello ]]--

local HandshakeHello = Request:extend()
function HandshakeHello:initialize(token, agentId)
  Request.initialize(self)
  self.method = 'handshake.hello'
  self.token = token
  self.agentId = agentId
end

function HandshakeHello:serialize(msgId)
  self.params.token = self.token
  self.params.agent_id = self.agentId
  return Request.serialize(self, msgId)
end

--[[ Ping ]]--
local Ping = Request:extend()
function Ping:initialize(timestamp)
  Request.initialize(self)
  self.method = 'heartbeat.ping'
  self.timestamp = timestamp
end

function Ping:serialize(msgId)
  self.params.timestamp = self.timestamp
  return Request.serialize(self, msgId)
end

--[[ Exports ]]--

local exports = {}
exports.Request = Request
exports.Response = Response
exports.HandshakeHello = HandshakeHello
exports.Ping = Ping
return exports
