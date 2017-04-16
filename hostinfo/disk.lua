--[[
Copyright 2014 Rackspace

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
local HostInfo = require('./base').HostInfo
local sigar = require('sigar')
local diskTargets = require('../util').diskTargets

local table = require('table')

--[[ Info ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
  local ctx, disks, usage_fields
  ctx = sigar:new()
  disks = diskTargets(ctx)
  usage_fields = {
    'read_bytes',
    'reads',
    'rtime',
    'time',
    'write_bytes',
    'writes',
    'wtime'
  }
  for i=1, #disks do
    local name = disks[i]:name()
    local usage = disks[i]:usage()
    if name and usage then
      local obj = {}
      for _, v in pairs(usage_fields) do
        obj[v] = usage[v]
      end
      obj['name'] = name
      table.insert(self._params, obj)
    end
  end
end

function Info:getType()
  return 'DISK'
end

return Info
