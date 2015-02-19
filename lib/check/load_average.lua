local os = require('os')
local BaseCheck = require('./base').BaseCheck
local CheckResult = require('./base').CheckResult
local logging = require('logging')

local LoadAverageCheck = BaseCheck:extend()

function LoadAverageCheck:initialize(params)
  BaseCheck.initialize(self, params)
end

function LoadAverageCheck:getType()
  return 'agent.load_average'
end

function LoadAverageCheck:run(callback)
  local s = sigar:new()
  local err, load = pcall(function() return s:load() end)
  local checkResult = CheckResult:new(self, {})

  -- Check the os to make sure if it is supported
  if os.type() == 'win32' then
    logging.error("Load Average checks are not supported on Windows.")
    checkResult:setStatus('unavailable')
    checkResult:setError('Load Average checks are not supported on Windows.')
    callback(checkResult)
    return
  end

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
