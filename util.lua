--[[
Copyright 2015 Rackspace

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
local sigar = require('sigar')
local los = require('los')
local table = require('table')

function exports.diskTargets(sigarCtx)
  local targets = {}
  local s = sigarCtx
  if not s then s = sigar:new() end
  local disks = s:disks()
  for i=1, #disks do
    local name = disks[i]:name()
    if los.type() == "win32" then
      table.insert(targets, disks[i])
    else
      -- Only target real Unix disks for now
      if name:find('/dev/') == 1 then
        table.insert(targets, disks[i])
      end
    end
  end
  return targets
end
