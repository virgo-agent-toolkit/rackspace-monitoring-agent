local BaseCheck = require('./base').BaseCheck
local CheckResult = require('./base').CheckResult

local NetworkCheck = BaseCheck:extend()

function NetworkCheck:initialize(params)
  BaseCheck.initialize(self, params, 'agent.network')
end

function NetworkCheck:run(callback)
  -- Perform Check
  local s = sigar:new()
  local netifs = s:netifs()
  local checkResult = CheckResult:new(self, {})
  local usage

  for i=1, #netifs do
    local usage = netifs[i]:usage()
    if usage then
      for key, value in pairs(usage) do
        checkResult:addMetric(key, nil, i, value)
      end
    end
  end

  -- Return Result
  self._lastResults = checkResult
  callback(checkResult)
end

local exports = {}
exports.NetworkCheck = NetworkCheck
return exports
