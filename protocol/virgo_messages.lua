local msg = require('./messages')

--[[ Manifest.get ]]--
local Manifest = msg.Request:extend()
function Manifest:initialize()
  msg.Request.initialize(self)
  self.method = 'check_schedule.get'
end

function Manifest:serialize(msgId)
  self.params.blah = 1
  return msg.Request.serialize(self, msgId)
end

--[[ System Info ]]--
local SystemInfoResponse = msg.Response:extend()
function SystemInfoResponse:initialize(replyToMsg, result)
  msg.Response.initialize(self, replyToMsg)

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
  return msg.Response.serialize(self, msgId)
end

--[[ Metrics Request ]]--
local MetricsRequest = msg.Request:extend()
function MetricsRequest:initialize(check, checkResult)
  msg.Request.initialize(self)
  self.check = check
  self.checkResult = checkResult
  self.method = 'check_metrics.post'
end

function MetricsRequest:serialize(msgId)
  self.params.state = self.checkResult:getState()
  self.params.status = self.checkResult:getStatus()
  self.params.metrics = self.checkResult:serialize()
  self.params.timestamp = self.checkResult:getTimestamp()
  self.params.check_id = self.check.id
  self.params.check_type = self.check.getType()
  return msg.Request.serialize(self, msgId)
end

--[[ Raw Metrics Request ]]--
local RawMetricsRequest = msg.Request:extend()
function RawMetricsRequest:initialize(metrics)
  msg.Request.initialize(self)
  self.metrics = metrics
  self.method = 'metrics.post'
end

function RawMetricsRequest:serialize(msgId)
  return msg.Request.serialize(self, msgId)
end

--[[ ScheduleChangeAck ]]--
local ScheduleChangeAck = msg.Response:extend()
function ScheduleChangeAck:initialize(replyTo)
  msg.Response.initialize(self, replyTo)
end

function ScheduleChangeAck:serialize(msgId)
  return msg.Response.serialize(self, msgId)
end

--[[ HostInfoResponse ]]--
local HostInfoResponse = msg.Response:extend()
function HostInfoResponse:initialize(replyTo, info)
  msg.Response.initialize(self, replyTo)
  self.result = info
end

function HostInfoResponse:serialize(msgId)
  return msg.Response.serialize(self, msgId)
end

--[[ CheckTestResponse ]]--
local CheckTestResponse = msg.Response:extend()
function CheckTestResponse:initialize(replyTo, result)
  msg.Response.initialize(self, replyTo)
  self.result.metrics = result:serialize()
  self.result.state = result:getState()
  self.result.status = result:getStatus()
end

function CheckTestResponse:serialize(msgId)
  return msg.Response.serialize(self, msgId)
end

--[[ CheckTargetsResponse ]]--
local CheckTargetsResponse = msg.Response:extend()
function CheckTargetsResponse:initialize(replyTo, targets)
  msg.Response.initialize(self, replyTo)
  self.result.targets = targets
end

function CheckTargetsResponse:serialize(msgId)
  return msg.Response.serialize(self, msgId)
end

local exports = {}
exports.Manifest = Manifest
exports.BinaryUpgradeRequest = BinaryUpgrade
exports.BundleUpgradeRequest = BundleUpgrade
exports.MetricsRequest = MetricsRequest
exports.RawMetricsRequest = RawMetricsRequest
exports.SystemInfoResponse = SystemInfoResponse
exports.ScheduleChangeAck = ScheduleChangeAck
exports.HostInfoResponse = HostInfoResponse
exports.CheckTestResponse = CheckTestResponse
exports.CheckTargetsResponse = CheckTargetsResponse
return exports
