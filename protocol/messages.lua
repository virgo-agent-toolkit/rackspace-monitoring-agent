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

-- [[ Response ]]--
local Response = Message:extend()
function Response:initialize(replyToMsg, result)
  Message.initialize(self)
  if replyToMsg then
    self.id = replyToMsg.id
    self.target = replyToMsg.source
    self.source = replyToMsg.target
  end
  self.result = result or {}
end

function Response:serialize(msgId)
  return {
    v = '1',
    id = self.id,
    target = self.target,
    source = self.source,
    result = self.result
  }
end

--[[ Request ]]--

local Request = Message:extend()

function Request:initialize()
  Message.initialize(self)
  self.method = ''
  self.params = {}
end

function Request:serialize(msgId)
  self.id = tostring(msgId)

  return {
    v = '1',
    id = self.id,
    target = self.target,
    source = self.source,
    method = self.method,
    params = self.params
  }
end

local BundleUpgrade = Request:extend()
function BundleUpgrade:initialize()
  Request.initialize(self)
  self.params.noop = 1
  self.method = 'bundle_upgrade.get_version'
end

local BinaryUpgrade = Request:extend()
function BinaryUpgrade:initialize()
  Request.initialize(self)
  self.params.noop = 1
  self.method = 'binary_upgrade.get_version'
end
--[[ Handshake.Hello ]]--

local HandshakeHello = Request:extend()
function HandshakeHello:initialize(token, agentId)
  Request.initialize(self)
  self.method = 'handshake.hello'
  self.params.token = token
  self.params.agent_id = agentId
  self.params.agent_name = 'Rackspace Monitoring Agent'
  self.params.process_version = virgo.virgo_version
  self.params.bundle_version = virgo.bundle_version
end

--[[ Heartbeat ]]--
local Heartbeat = Request:extend()
function Heartbeat:initialize(timestamp)
  Request.initialize(self)
  self.method = 'heartbeat.post'
  self.timestamp = timestamp
end

function Heartbeat:serialize(msgId)
  self.params.timestamp = self.timestamp
  return Request.serialize(self, msgId)
end

--[[ Exports ]]--
local exports = {}
exports.Request = Request
exports.Response = Response
exports.HandshakeHello = HandshakeHello
exports.Heartbeat = Heartbeat
exports.BinaryUpgradeRequest = BinaryUpgrade
exports.BundleUpgradeRequest = BundleUpgrade
return exports
