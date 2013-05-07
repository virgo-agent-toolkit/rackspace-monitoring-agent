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
  local swapinfo = s:swap()
  local checkResult = CheckResult:new(self, {})
  local metrics = {
    actual_used = 'bytes',
    free = 'bytes',
    total = 'bytes',
    ram = 'megabytes',
    actual_free = 'bytes',
    used = 'bytes'
  }
  local swap_metrics = {
    total = 'bytes',
    used = 'bytes',
    free = 'bytes',
    page_in = 'bytes',
    page_out = 'bytes'
  }

  for key, unit in pairs(metrics) do
    checkResult:addMetric(key, nil, 'gauge', meminfo[key], unit)
  end

  for key, unit in pairs(swap_metrics) do
    checkResult:addMetric('swap_' .. key, nil, 'gauge', swapinfo[key], unit)
  end

  -- Return Result
  self._lastResult = checkResult
  callback(checkResult)
end

local exports = {}
exports.MemoryCheck = MemoryCheck
return exports
