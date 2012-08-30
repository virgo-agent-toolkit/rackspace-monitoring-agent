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

local BaseCheck = require('./base').BaseCheck
local CheckResult = require('./base').CheckResult

local MemoryCheck = BaseCheck:extend()

function MemoryCheck:initialize(params)
  BaseCheck.initialize(self, 'agent.memory', params)
end

function MemoryCheck:run(callback)
  -- Perform Check
  local s = sigar:new()
  local meminfo = s:mem()
  local checkResult = CheckResult:new(self, {})
  local percent_metrics = {
    'used_percent',
    'free_percent'
  }
  local metrics = {
    'actual_used',
    'free',
    'total',
    'ram',
    'actual_free',
    'used'
  }

  for _, key in pairs(percent_metrics) do
    checkResult:addMetric(key, nil, nil, meminfo[key])
  end

  for _, key in pairs(metrics) do
    checkResult:addMetric(key, nil, 'gauge', meminfo[key])
  end

  -- Return Result
  self._lastResult = checkResult
  callback(checkResult)
end

local exports = {}
exports.MemoryCheck = MemoryCheck
return exports
