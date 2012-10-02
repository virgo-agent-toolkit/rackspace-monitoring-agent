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
local version = require('../util/version')

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

local BundleUpdate = Request:extend()
function BundleUpdate:initialize()
  Request.initialize(self)
  self.method = 'bundle_upgrade.get_version'
end

local BinaryUpdate = Request:extend()
function BinaryUpdate:initialize()
  Request.initialize(self)
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
  self.params.process_version = version.process
  self.params.bundle_version = version.bundle
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

--[[ Manifest.get ]]--
local Manifest = Request:extend()
function Manifest:initialize()
  Request.initialize(self)
  self.method = 'check_schedule.get'
end

function Manifest:serialize(msgId)
  self.params.blah = 1
  return Request.serialize(self, msgId)
end

--[[ System Info ]]--
local SystemInfoResponse = Response:extend()
function SystemInfoResponse:initialize(replyToMsg, result)
  Response.initialize(self)

  local s = sigar:new()
  local cpus = s:cpus()
  local netifs = s:netifs()

  self.sysinfo = s:sysinfo()
  self.netifs = {}
  self.cpus = {}

  for i=1,#cpus do
    self.cpus[i] = {}
    self.cpus[i].info = cpus[i]:info()
    self.cpus[i].data = cpus[i]:data()
  end

  for i=1,#netifs do
    self.netifs[i] = {}
    self.netifs[i].info = netifs[i]:info()
    self.netifs[i].usage = netifs[i]:usage()
  end
end

function SystemInfoResponse:serialize(msgId)
  self.result.sysinfo = self.sysinfo
  self.result.cpus = self.cpus
  self.result.netifs = self.netifs
  return Response.serialize(self, msgId)
end

--[[ Metrics Request ]]--
local MetricsRequest = Request:extend()
function MetricsRequest:initialize(check, checkResults)
  Request.initialize(self)
  self.check = check
  self.checkResults = checkResults
  self.method = 'check_metrics.post'
end

function MetricsRequest:serialize(msgId)
  self.params.state = self.checkResults:getState()
  self.params.status = self.checkResults:getStatus()
  self.params.metrics = self.checkResults:serialize()
  self.params.timestamp = self.checkResults:getTimestamp()
  self.params.check_id = self.check.id
  self.params.check_type = self.check._type
  return Request.serialize(self, msgId)
end

--[[ ScheduleChangeAck ]]--
local ScheduleChangeAck = Response:extend()
function ScheduleChangeAck:initialize(replyTo)
  Response.initialize(self, replyTo)
end

function ScheduleChangeAck:serialize(msgId)
  return Response.serialize(self, msgId)
end

--[[ HostInfoResponse ]]--
local HostInfoResponse = Response:extend()
function HostInfoResponse:initialize(replyTo, info)
  Response.initialize(self, replyTo)
  self.result = info
end

function HostInfoResponse:serialize(msgId)
  return Response.serialize(self, msgId)
end

--[[ CheckTestResponse ]]--
local CheckTestResponse = Response:extend()
function CheckTestResponse:initialize(replyTo, result)
  Response.initialize(self, replyTo)
  self.result.metrics = result:serialize()
  self.result.state = result:getState()
  self.result.status = result:getStatus()
end

function CheckTestResponse:serialize(msgId)
  return Response.serialize(self, msgId)
end

--[[ Exports ]]--
local exports = {}
exports.Request = Request
exports.Response = Response
exports.HandshakeHello = HandshakeHello
exports.Heartbeat = Heartbeat
exports.Manifest = Manifest
exports.BinaryUpdateRequest = BinaryUpdate
exports.BundleUpdateRequest = BundleUpdate
exports.MetricsRequest = MetricsRequest
exports.SystemInfoResponse = SystemInfoResponse
exports.ScheduleChangeAck = ScheduleChangeAck
exports.HostInfoResponse = HostInfoResponse
exports.CheckTestResponse = CheckTestResponse
return exports
