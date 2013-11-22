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

--[[ db ]]--

local db = {}
db.checks = {}
db.alarms = {}
db.notification = {}
db.notification_plan = {}

--[[ db.checks.create ]]--
db.checks.create = Request:extend()
function db.checks.create:initialize(params)
  Request.initialize(self)
  self.method = 'db.checks.create'
  self.params = params
end

--[[ db.checks.get_all ]]--
db.checks.get_all = Request:extend()
function db.checks.get_all:initialize(params)
  Request.initialize(self)
  self.method = 'db.checks.get_all'
  self.params = params
end

--[[ db.checks.get ]]--
db.checks.get = Request:extend()
function db.checks.get:initialize(entityId, checkId)
  Request.initialize(self)
  self.method = 'db.checks.get'
  self.params = {entity_id = entityId, check_id = checkId}
end

--[[ db.checks.remove ]]--
db.checks.remove = Request:extend()
function db.checks.remove:initialize(entityId, checkId)
  Request.initialize(self)
  self.method = 'db.checks.remove'
  self.params = {entity_id = entityId, check_id = checkId}
end

--[[ db.alarms.create ]]--
db.alarms.create = Request:extend()
function db.alarms.create:initialize(entityId, checkId, criteria, npId)
  Request.initialize(self)
  self.method = 'db.alarms.create'
  self.params = {
    entity_id = entityId,
    check_id = checkId,
    criteria = criteria,
    notification_plan_id = npId
  }
end

--[[ db.alarms.get ]]--
db.alarms.get = Request:extend()
function db.alarms.get:initialize(entityId, alarmId)
  Request.initialize(self)
  self.method = 'db.alarms.get'
  self.params = {
    entity_id = entityId,
    alarm_id = alarmId
  }
end

--[[ db.alarms.remove ]]--
db.alarms.remove = Request:extend()
function db.alarms.remove:initialize(entityId, alarmId)
  Request.initialize(self)
  self.method = 'db.alarms.remove'
  self.params = {
    entity_id = entityId,
    alarm_id = alarmId
  }
end

--[[ db.notification.remove ]]--
db.notification.remove = Request:extend()
function db.notification.remove:initialize(notificationId)
  Request.initialize(self)
  self.method = 'db.notification.remove'
  self.params = { notification_id = notification_id }
end

--[[ db.notification.get ]]--
db.notification.get = Request:extend()
function db.notification.get:initialize(notificationId)
  Request.initialize(self)
  self.method = 'db.notification.get'
  self.params = { notification_id = notificationId }
end

--[[ db.notification.list ]]--
db.notification.list = Request:extend()
function db.notification.list:initialize()
  Request.initialize(self)
  self.method = 'db.notification.list'
  self.params = { nop = '1' }
end

--[[ db.notification.create ]]--
db.notification.create = Request:extend()
function db.notification.create:initialize(params)
  Request.initialize(self)
  self.method = 'db.notification.create'
  self.params = params
end

--[[ db.notification_plan.remove ]]--
db.notification_plan.remove = Request:extend()
function db.notification_plan.remove:initialize(notificationId)
  Request.initialize(self)
  self.method = 'db.notification_plan.remove'
  self.params = { notification_id = notification_id }
end

--[[ db.notification_plan.get ]]--
db.notification_plan.get = Request:extend()
function db.notification_plan.get:initialize(notificationId)
  Request.initialize(self)
  self.method = 'db.notification_plan.get'
  self.params = { notification_id = notificationId }
end

--[[ db.notification_plan.list ]]--
db.notification_plan.list = Request:extend()
function db.notification_plan.list:initialize()
  Request.initialize(self)
  self.method = 'db.notification_plan.list'
  self.params = { nop = '1' }
end

--[[ db.notifications.create ]]--
db.notification_plan.create = Request:extend()
function db.notification_plan.create:initialize(params)
  Request.initialize(self)
  self.method = 'db.notification_plan.create'
  self.params = params
end

--[[ Exports ]]--
local exports = {}
exports.db = db
exports.Request = Request
exports.Response = Response
exports.HandshakeHello = HandshakeHello
exports.Heartbeat = Heartbeat
exports.Manifest = Manifest
exports.BinaryUpgradeRequest = BinaryUpgrade
exports.BundleUpgradeRequest = BundleUpgrade
return exports
