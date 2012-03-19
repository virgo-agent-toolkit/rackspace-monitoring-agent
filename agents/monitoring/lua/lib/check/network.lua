local BaseCheck = require('./base').BaseCheck
local CheckResult = require('./base').CheckResult

local NetworkCheck = BaseCheck:extend()

function NetworkCheck:initialize(params)
  BaseCheck.initialize(self, params, 'Network')
end

function NetworkCheck:run(callback)
  -- Perform Check
  local s = sigar:new()
  local netifs = s:netifs()
  local metrics = {}

  for i=1, #netifs do 
    metrics[i] = {}
    metrics[i].info = netifs[i]:info()
    metrics[i].usage = netifs[i]:usage()
  end

  -- Return Result
  local checkResult = CheckResult:new(self, {}, metrics)
  self._lastResults = checkResult
  callback(checkResult)
end

local exports = {}
exports.NetworkCheck = NetworkCheck
return exports
