local BaseCheck = require('./base').BaseCheck
local CheckResult = require('./base').CheckResult

local LoadAverageCheck = BaseCheck:extend()

function LoadAverageCheck:initialize(params)
  BaseCheck.initialize(self, 'agent.load_average', params)
end

function LoadAverageCheck:run(callback)
  local s = sigar:new()
  local err, load = pcall(function() return s:load() end)
  local checkResult = CheckResult:new(self, {})

  if err == true then
    for key, value in pairs(load) do
      checkResult:addMetric(key, nil, 'double', value)
    end
  else
    checkResult:setError(load)
  end

  self._lastResult = checkResult
  callback(checkResult)
end

local exports = {}
exports.LoadAverageCheck = LoadAverageCheck
return exports
