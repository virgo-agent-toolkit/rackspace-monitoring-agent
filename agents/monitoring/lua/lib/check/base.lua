--[[
Copyright 2012 Rackspace

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]

local os = require('os')
local Object = require('core').Object
local Emitter = require('core').Emitter

local BaseCheck = Emitter:extend()
local CheckResult = Object:extend()

function BaseCheck:initialize(params)
  self._lastResults = nil
  self.state = params.state
  self.id = params.id
  self.period = params.period
  self.path = params.path
end

function BaseCheck:run(callback)
  -- do something, produce a CheckResult
  local checkResult = CheckResult:new({})
  self._lastResults = checkResult
  callback(checkResult)
end

function BaseCheck:getNextRun()
  if self._lastResults then
    return self._lastResults._nextRun
  else
    return os.time() 
  end
end

function CheckResult:initialize(options, metrics)
  self._options = options or {}
  self._metrics = metrics or {}
  self._nextRun = os.time() + 30; -- default to 30 seconds now.
end

function CheckResult:setMetric(key, value)
  self._metrics[key] = value
end

function CheckResult:setMetricWithObject(metrics)
  for key, value in pairs(metrics) do
    self._metrics[key] = value
  end
end


-- todo: serialize/deserialize methods.

local exports = {}
exports.BaseCheck = BaseCheck
exports.CheckResult = CheckResult
return exports
