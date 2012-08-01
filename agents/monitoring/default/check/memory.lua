local BaseCheck = require('./base').BaseCheck
local CheckResult = require('./base').CheckResult

local MemoryCheck = BaseCheck:extend()

function MemoryCheck:initialize(params)
  BaseCheck.initialize(self, 'agent.memory', params)
end

function MemoryCheck:run(callback)
  -- Perform Check
  local s = sigar:new()
  local meminfo = s:mem()
  local checkResult = CheckResult:new(self, {})

  for key, value in pairs(meminfo) do
    checkResult:addMetric(key, 'memory', 'gauge', value)
  end

  -- Return Result
  self._lastResult = checkResult
  callback(checkResult)
end

local exports = {}
exports.MemoryCheck = MemoryCheck
return exports
