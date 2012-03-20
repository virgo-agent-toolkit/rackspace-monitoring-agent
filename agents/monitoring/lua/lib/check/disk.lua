local BaseCheck = require('./base').BaseCheck
local CheckResult = require('./base').CheckResult

local DiskCheck = BaseCheck:extend()

function DiskCheck:initialize(params)
  BaseCheck.initialize(self, params, 'agent.disk')
end

function DiskCheck:run(callback)
  -- Perform Check
  local s = sigar:new()
  local disks = s:disks()
  local checkResult = CheckResult:new(self, {})
  local name, usage

  for i=1, #disks do
    name = disks[i]:name()
    usage = disks[i]:usage()

    if usage then
      for key, value in pairs(usage) do
        checkResult:addMetric(key, nil, name, value)
      end
    end
  end

  -- Return Result
  self._lastResults = checkResult
  callback(checkResult)
end

local exports = {}
exports.DiskCheck = DiskCheck
return exports
