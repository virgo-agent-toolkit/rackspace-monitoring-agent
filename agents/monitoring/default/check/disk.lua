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

local DiskCheck = BaseCheck:extend()

function DiskCheck:initialize(params)
  BaseCheck.initialize(self, 'agent.disk', params)

  if params.details == nil then
    params.details = {}
  end

  self.dev_name = params.details.target and params.details.target or nil
end

-- Dimension key is the mount point name, e.g. /, /home

function DiskCheck:run(callback)
  -- Perform Check
  local s = sigar:new()
  local disks = s:disks()
  local checkResult = CheckResult:new(self, {})
  local name, usage
  local metrics = {
    'reads',
    'writes',
    'read_bytes',
    'write_bytes',
    'rtime',
    'wtime',
    'qtime',
    'time',
    'service_time',
    'queue'
  }

  if self.dev_name == nil then
    checkResult:setError('Missing target parameter')
    callback(checkResult)
    return
  end

  -- Find the requested disk
  for i=1, #disks do
    if disks[i]:name() == self.dev_name then
      usage = disks[i]:usage()

      if usage then
        for _, key in pairs(metrics) do
          checkResult:addMetric(key, nil, nil, usage[key])
        end
      else
        checkResult:setError(fmt('Unable to access disk usage metrics for %s', self.dev_name))
      end

      callback(checkResult)
      return
    end
  end

  checkResult:setError(fmt('No such disk: %s', self.dev_name))
  callback(checkResult)
end

local exports = {}
exports.DiskCheck = DiskCheck
return exports
