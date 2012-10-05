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

local FileSystemCheck = BaseCheck:extend()

local METRICS = {
  'total',
  'free',
  'used',
  'avail',
  'files',
  'free_files',
}

function FileSystemCheck:initialize(params)
  BaseCheck.initialize(self, 'agent.filesystem', params)
end

-- Dimension key is the mount point name, e.g. /, /home
function FileSystemCheck:run(callback)
  -- Perform Check
  local s = sigar:new()
  local fses = s:filesystems()
  local checkResult = CheckResult:new(self, {})
  local fs, info, usage, value, used_percent

  for i=1, #fses do
    fs = fses[i]
    info = fs:info()
    usage = fs:usage()

    name = info['dir_name']

    if name and usage then
      for _, key in pairs(METRICS) do
        value = usage[key]
        checkResult:addMetric(key, name, nil, value)
      end
    end

    if usage and usage['total'] > 0 then
      free_percent = (usage['avail'] / usage['total']) * 100
      used_percent = (usage['used'] / usage['total']) * 100

      checkResult:addMetric('free_percent', name, nil, free_percent)
      checkResult:addMetric('used_percent', name, nil, used_percent)
    end
  end

  -- Return Result
  self._lastResult = checkResult
  callback(checkResult)
end

local exports = {}
exports.FileSystemCheck = FileSystemCheck
return exports
