local BaseCheck = require('./base').BaseCheck
local CheckResult = require('./base').CheckResult

local DiskCheck = BaseCheck:extend()

function DiskCheck:initialize(params)
  BaseCheck.initialize(self, params)
end

function DiskCheck:run(callback)
  -- Perform Check
  local s = sigar:new()
  local disks = s:disks()
  local metrics = {}

  for i=1, #disks do
    metrics[i] = {}
    metrics[i].name = disks[i]:name()
    metrics[i].usage = disks[i]:usage()
  end

  -- Return Result
  local checkResult = CheckResult:new({}, metrics)
  self._lastResults = checkResult
  callback(checkResult)
end

local exports = {}
exports.DiskCheck = DiskCheck
return exports
