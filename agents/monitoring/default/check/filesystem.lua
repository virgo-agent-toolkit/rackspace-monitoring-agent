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
local fmt = require('string').format

local BaseCheck = require('./base').BaseCheck
local CheckResult = require('./base').CheckResult
local table = require('table')

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

  if params.details == nil then
    params.details = {}
  end

  self.mount_point = params.details.target and params.details.target or nil
end

function FileSystemCheck:getTargets(callback)
  local s = sigar:new()
  local fses = s:filesystems()
  local info, fs
  local targets = {}
  for i=1, #fses do
    fs = fses[i]
    info = fs:info()
    table.insert(targets, info['dir_name'])
  end
  callback(nil, targets)
end

-- Dimension key is the mount point name, e.g. /, /home
function FileSystemCheck:run(callback)
  -- Perform Check
  local s = sigar:new()
  local fses = s:filesystems()
  local checkResult = CheckResult:new(self, {})
  local fs, info, usage, value
  local found = false

  if self.mount_point == nil then
    checkResult:setError('Missing target parameter')
    callback(checkResult)
    return
  end

  for i=1, #fses do
    fs = fses[i]
    info = fs:info()

    -- Search for the mount point we want. TODO: modify sigar bindings to
    -- let us do a lookup from this.
    if info['dir_name'] == self.mount_point then
      found = true
      usage = fs:usage()

      if usage then
        for _, key in pairs(METRICS) do
          value = usage[key]
          checkResult:addMetric(key, nil, nil, value)
        end
      end

      -- Return Result
      callback(checkResult)
      return
    end
  end

  checkResult:setError(fmt('No filesystem mounted at %s', self.mount_point))
  callback(checkResult)
end

local exports = {}
exports.FileSystemCheck = FileSystemCheck
return exports
