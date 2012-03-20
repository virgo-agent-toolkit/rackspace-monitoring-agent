local BaseCheck = require('./base').BaseCheck
local CheckResult = require('./base').CheckResult

local MemoryCheck = BaseCheck:extend()

function MemoryCheck:initialize(params)
  BaseCheck.initialize(self, params, 'agent.memory')
end

function MemoryCheck:run(callback)
  -- Perform Check
  local s = sigar:new()
  local meminfo = {}
  meminfo[1]  = s:mem()

  -- Return Result
  local checkResult = CheckResult:new(self, {}, meminfo)
  self._lastResults = checkResult
  callback(checkResult)
end

local exports = {}
exports.MemoryCheck = MemoryCheck
return exports
