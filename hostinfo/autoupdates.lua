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

local fmt = require('string').format
local los = require('los')
local sigar = require('sigar')
local table = require('table')
local execFileToBuffers = require('./misc').execFileToBuffers

--[[ Are autoupdates enabled? ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  if los.type() ~= 'linux' then
    self._error = 'Unsupported OS for Packages'
    return callback()
  end

  local vendor, statcmd, statargs, method, options, status, errTable
  vendor = sigar:new():sysinfo().vendor:lower()
  errTable = {}

  if vendor == 'ubuntu' or vendor == 'debian' then
    statcmd = 'apt-config'
    statargs = {'dump' }
    method = 'unattended_upgrades'
    options = {}
  elseif vendor == 'rhel' or vendor == 'centos' then
    statcmd = 'service'
    statargs = {'yum-cron', 'status' }
    method = 'yum_cron'
    options = {}
  else
    self._error = 'Could not determine linux distro for autoupdates'
    return callback()
  end

  local function statExecCb(err, exitcode, stdout_data, stderr_data)
    status = 'disabled'
    if exitcode ~= 0 then
      self._error = fmt("Autoupdates check exited with a %d exitcode", exitcode)
      return callback()
    end
    if vendor == 'rhel' or vender == 'centos' then
      status = 'enabled'
    elseif vendor == 'ubuntu' or vendor == 'debian' then
      for line in stdout_data:gmatch("[^\r\n]+") do
        local _, _, key, value = line:find("(.*)%s(.*)")
        value, _ = value:gsub('"', ''):gsub(';', '')
        if key == 'APT::Periodic::Unattended-Upgrade' and value ~= 0 then
          status = 'enabled'
        end
      end
    end
    table.insert(self._params, {
      update_method = method,
      status = status
    })
    return callback()
  end
  return execFileToBuffers(statcmd, statargs, options, statExecCb)
end

function Info:getType()
  return 'AUTOUPDATES'
end

return Info
