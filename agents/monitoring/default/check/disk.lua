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

local DiskCheck = BaseCheck:extend()

function DiskCheck:initialize(params)
  BaseCheck.initialize(self, 'agent.disk', params)
end

-- Dimension key is the mount point name, e.g. /, /home

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
        checkResult:addMetric(key, name, nil, value)
      end
    end
  end

  -- Return Result
  self._lastResult = checkResult
  callback(checkResult)
end

local exports = {}
exports.DiskCheck = DiskCheck
return exports
