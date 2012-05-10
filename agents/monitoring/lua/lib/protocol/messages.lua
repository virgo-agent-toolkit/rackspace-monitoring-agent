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

--[[ Manifest.get ]]--
local Manifest = Request:extend()
function Manifest:initialize()
  Request.initialize(self)
  self.method = 'manifest.get'
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
  self.method = 'metrics.set'
end

function MetricsRequest:serialize(msgId)
  self.params.metrics = self.checkResults:serialize()
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

--[[ Exports ]]--
local exports = {}
exports.Request = Request
exports.Response = Response
exports.HandshakeHello = HandshakeHello
exports.Ping = Ping
exports.Manifest = Manifest
exports.MetricsRequest = MetricsRequest
exports.SystemInfoResponse = SystemInfoResponse
exports.ScheduleChangeAck = ScheduleChangeAck
return exports
