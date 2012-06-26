local BaseCheck = require('./base').BaseCheck
local CheckResult = require('./base').CheckResult
local Metric = require('./base').Metric

local CpuCheck = BaseCheck:extend()

local DIMENSION_PREFIX = 'cpu.'

function CpuCheck:initialize(params)
  BaseCheck.initialize(self, params, 'agent.cpu')
end

function CpuCheck:run(callback)
  -- Perform Check
  local s = sigar:new()
  local cpuinfo = s:cpus()
  local metrics = {}
  local checkResult = CheckResult:new(self, {})

  for i=1, #cpuinfo do
    for key, value in pairs(cpuinfo[i]:data()) do
      local index = i - 1
      checkResult:addMetric(key, DIMENSION_PREFIX .. index, nil, value)
    end
  end

  -- Return Result
  self._lastResult = checkResult
  callback(checkResult)
end

local exports = {}
exports.CpuCheck = CpuCheck
return exports
