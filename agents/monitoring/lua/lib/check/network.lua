local BaseCheck = require('./base').BaseCheck
local CheckResult = require('./base').CheckResult

local NetworkCheck = BaseCheck:extend()

function NetworkCheck:initialize(params)
  BaseCheck.initialize(self, params, 'agent.network')
end

-- Dimension is is the interface name, e.g. eth0, lo0, etc

function NetworkCheck:run(callback)
  -- Perform Check
  local s = sigar:new()
  local netifs = s:netifs()
  local checkResult = CheckResult:new(self, {})
  local usage

  for i=1, #netifs do
    local usage = netifs[i]:usage()
    local info = netifs[i]:info()

    if usage then
      for key, value in pairs(usage) do
        checkResult:addMetric(key, info.name, value)
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
