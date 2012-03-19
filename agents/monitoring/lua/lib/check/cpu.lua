local BaseCheck = require('./base').BaseCheck
local CheckResult = require('./base').CheckResult

local CpuCheck = BaseCheck:extend()

function CpuCheck:initialize(params)
  BaseCheck.initialize(self, params, 'Cpu')
end

function CpuCheck:run(callback)
  -- Perform Check
  local s = sigar:new()
  local cpuinfo = s:cpus()
  local metrics = {}

  for i=1, #cpuinfo do
    metrics[i] = {}
    metrics[i].info = cpuinfo[i]:info()
    metrics[i].data = cpuinfo[i]:data()
  end

  -- Return Result
  local checkResult = CheckResult:new(self, {}, metrics)
  self._lastResults = checkResult
  callback(checkResult)
end

local exports = {}
exports.CpuCheck = CpuCheck
return exports
