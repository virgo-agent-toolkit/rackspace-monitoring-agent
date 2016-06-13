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

local GetOptionsStringForFs = require('./check/filesystem').GetOptionsStringForFs
local sigar = require('sigar')
local split = require('virgo/util/misc').split

local s = sigar:new()

local function gatherReadWriteReadOnlyInfo()
  local fses = s:filesystems()
  local fs_list_ro = {}
  local fs_list_rw = {}
  for i=1, #fses do
    local fs = fses[i]
    local info = fs:info()
    local options = GetOptionsStringForFs(info['dir_name'])
    local type_name = info['type_name']
    if options then
      for _, option in pairs(split(options, '[^,%s]+')) do
        if option == 'ro' and (type_name == 'local' or type_name == 'remote') then
          table.insert(fs_list_ro, info['dev_name'])
          break
        elseif option == 'rw' and (type_name == 'local' or type_name == 'remote') then
          table.insert(fs_list_rw, info['dev_name'])
          break
        end
      end
    end
  end
  return fs_list_ro, fs_list_rw
end

exports.gatherReadWriteReadOnlyInfo = gatherReadWriteReadOnlyInfo
