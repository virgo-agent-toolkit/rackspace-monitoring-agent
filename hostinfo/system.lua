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


--[[ System Info ]]--
local SystemInfo = HostInfo:extend()
function SystemInfo:initialize()
  HostInfo.initialize(self)
  local sysinfo = sigarCtx:sysinfo()
  local obj = {name = sysinfo.name, arch = sysinfo.arch,
               version = sysinfo.version, vendor = sysinfo.vendor,
               vendor_version = sysinfo.vendor_version,
               vendor_name = sysinfo.vendor_name or sysinfo.vendor_version}

  table.insert(self._params, obj)
end

function SystemInfo:getType()
  return 'SYSTEM'
end

local exports = {}
exports.SystemInfo = SystemInfo
return exports
