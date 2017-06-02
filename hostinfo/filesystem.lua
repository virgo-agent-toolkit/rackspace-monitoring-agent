--[[
Copyright 2016 Rackspace

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
local GetOptionsStringForFs = require('../check/filesystem').GetOptionsStringForFs

--[[ Filesystem Info ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end
function Info:_run(callback)
  local ctx = sigar:new()
  local fses = ctx:filesystems()
  for i=1, #fses do
    local obj = {}
    local fs = fses[i]
    local info = fs:info()
    local usage = fs:usage()
    if info then
      local info_fields = {
        'dir_name',
        'dev_name',
        'sys_type_name',
        'options',
      }
      for _, v in pairs(info_fields) do
        if v == 'options' then
          local opts = GetOptionsStringForFs(info.dir_name)
          if opts then
            obj[v] = opts
          else
            obj[v] = info[v]
          end
        else
          obj[v] = info[v]
        end
      end
    end

    if usage then
      local usage_fields = {
        'total',
        'free',
        'used',
        'avail',
        'files',
        'free_files',
      }
      for _, v in pairs(usage_fields) do
        obj[v] = usage[v]
      end
    end

    table.insert(self._params, obj)
  end
  callback()
end

function Info:getType()
  return 'FILESYSTEM'
end

return Info
