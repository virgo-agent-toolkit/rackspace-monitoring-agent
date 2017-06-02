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

--[[ System Info ]]--
local Info = HostInfo:extend()

function Info:initialize()
  HostInfo.initialize(self)
end
function Info:_run(callback)
  local ctx, sysinfo
  ctx = sigar:new()
  sysinfo = ctx:sysinfo()
  table.insert(self._params, {
    name = sysinfo.name,
    arch = sysinfo.arch,
    version = sysinfo.version,
    vendor = sysinfo.vendor,
    vendor_version = sysinfo.vendor_version,
    vendor_name = sysinfo.vendor_name or sysinfo.vendor_version
  })
  callback()
end

function Info:getType()
  return 'SYSTEM'
end

return Info
