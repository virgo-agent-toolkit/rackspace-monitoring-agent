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

local sigarCtx = require('/sigar').ctx
local sigarutil = require('/base/util/sigar')

local table = require('table')

--[[ Filesystem Info ]]--
local FilesystemInfo = HostInfo:extend()
function FilesystemInfo:initialize()
  HostInfo.initialize(self)
  local fses = sigarCtx:filesystems()
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
        obj[v] = info[v]
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
end

function FilesystemInfo:getType()
  return 'FILESYSTEM'
end

local exports = {}
exports.FilesystemInfo = FilesystemInfo
return exports
