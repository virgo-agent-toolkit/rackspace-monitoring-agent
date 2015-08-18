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
local streamingSpawn = require('./misc').streamingSpawn
local sigar = require('sigar')

--[[ Are autoupdates enabled? ]]--
local Info = HostInfo:extend()

function Info:run(callback)
  if self:isRestrictedPlatform() then return callback() end

  local vendor, statcmd, statargs, method, options, errTable, outTable
  vendor = sigar:new():sysinfo().vendor:lower()
  outTable, errTable, options = {} ,{}, {}

  if vendor == 'ubuntu' or vendor == 'debian' then
    statcmd = 'apt-config'
    statargs = {'dump' }
    method = 'unattended_upgrades'
  elseif vendor == 'rhel' or vendor == 'centos' then
    statcmd = 'service'
    statargs = {'yum-cron', 'status' }
    method = 'yum_cron'
  else
    self._error = 'Unsupported OS vendor for ' .. self:getType()
    return callback()
  end

  local status = 'disabled'
  -- Define how we handle lines
  local function casterFunc(line, callback)
    if vendor == 'rhel' or vender == 'centos' then
      status = 'enabled'
    elseif vendor == 'ubuntu' or vendor == 'debian' then
      local _, _, key, value = line:find("(.*)%s(.*)")
      value, _ = value:gsub('"', ''):gsub(';', '')
      if key == 'APT::Periodic::Unattended-Upgrade' and value ~= 0 then
        status = 'enabled'
      end
    end
    return callback()
  end

  local function finalCb()
    self:pushParams({
      update_method = method,
      status = status
    }, errTable)
    return callback()
  end

  streamingSpawn(statcmd, statargs, options, outTable, errTable, casterFunc, finalCb)
end

function Info:getRestrictedPlatforms()
  return {'win32'}
end

function Info:getType()
  return 'AUTOUPDATES'
end

return Info
