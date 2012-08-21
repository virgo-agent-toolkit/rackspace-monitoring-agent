local BaseCheck = require('./base').BaseCheck
local CheckResult = require('./base').CheckResult

local LoadCheck = BaseCheck:extend()

function LoadCheck:initialize(params)
  BaseCheck.initialize(self, 'agent.load', params)
end

function LoadCheck:run(callback)
  local s = sigar:new()
  local err, load = pcall(s:load)
  local checkResult = CheckResult:new(self, {})

  if err == true then
    for key, value in pairs(load) do
      checkResult:addMetric(key, 'load', 'double', value)
    end
  else
    checkResult:setError(load)
  end

  self._lastResult = checkResult
  callback(checkResult)
end

local exports = {}
exports.LoadCheck = LoadCheck
return exports
