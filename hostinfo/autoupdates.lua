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

local string = require('string')
local fmt = require('string').format
local table = require('table')
local os = require('os')
local sctx = require('../sigar').ctx
local spawn = require('childprocess').spawn

--[[ Sysctl Variables ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:run(callback)

  if os.type() ~= 'Linux' then
    self._error = 'Unsupported OS for Autoupdates'
    callback()
    return
  end

  local sysinfo = sctx:sysinfo()
  local packages_child = ''
  local status_child = ''
  local status_exit = 0
  local updates = {}
  local vendor = sysinfo.vendor:lower()

  if vendor == 'ubuntu' or vendor == 'debian' then
    vendor = 'debian'
    packages_child = spawn('dpkg-query', {'-W'}, {})
    status_child = spawn('apt-config', {'dump'}, {})
    updates['method'] = 'unattended_upgrades'
  elseif vendor == 'rhel' or vendor == 'centos' then
    vendor = 'rhel'
    package_cmd = 'rpm'
    packages_child = spawn('rpm', {"-qa", '--queryformat', '%{NAME}: %{VERSION}-%{RELEASE}\n'}, {})
    status_child = spawn('service', {'yum-cron', 'status'}, {})
    updates['method'] = 'yum_cron'
  else
    self._error = 'Undetected or Unsupported OS for Autoupdates'
    callback()
    return
  end

  local collection_count = 0

  function collectData(data)
    if data ~= nil then
      for k, v in pairs(data) do
        updates[k] = v
      end
    end
    collection_count = collection_count + 1
    if collection_count > 1 then
      table.insert(self._params, updates)
      callback()
    end
  end

  local package_data = ''
  local status_data = ''

  packages_child.stdout:on('data', function(chunk)
    package_data = package_data .. chunk
  end)

  packages_child:on('error', function(err)
    self._error = err
    callback()
  end)

  packages_child:on('exit', function(exit_code)
    if exit_code ~= 0 then
      self._error = fmt("Autoupdates packages command exited with a %d exit_code", exitcode)
      callback()
      return
    end
  end)

  packages_child.stdout:on('end', function()
    local packages = {['package'] = 'uninstalled'}
    local line
    for line in package_data:gmatch("[^\r\n]+") do
      line = line:gsub("^%s*(.-)%s*$", "%1")
      local a, b, key, value = line:find("(.*)%s(.*)")
      key, _ = key:gsub(':','')
      if key ~= nil then
        if key == 'unattended-upgrades' then
          packages = {['package'] = 'installed'}
          break
        elseif key == 'yum-cron' then
          packages = {['package'] = 'installed'}
          break
        end
      end
    end
    collectData(packages)
  end)

  status_child.stdout:on('data', function(chunk)
    status_data = status_data .. chunk
  end)

  status_child:on('exit', function(exit_code)
    status_exit = exit_code
    local status = {}
    if exit_code ~= 0 then
      if vendor == 'rhel' then
        status = {['status'] = "disabled"}
        collectData(status)
        return
      end

      self._error = fmt("Autoupdates status command exited with a %d exit_code", exitcode)
      callback()
      return
    else
      if vendor == 'rhel' then
        status = {['status'] = 'enabled'}
        collectData(status)
        return
      end
    end
  end)

  status_child.stdout:on('end', function()
    if vendor == 'debian' then
      local status = {['status'] = "disabled"}
      local line
      for line in status_data:gmatch("[^\r\n]+") do
        local a, b, key, value = line:find("(.*)%s(.*)")
        value, _ = value:gsub('"',''):gsub(';','')
        if key == 'APT::Periodic::Unattended-Upgrade' and value == "1" then
          status = {['status'] = "enabled"}
          -- collectData(status)
          break
        end
      end
      collectData(status)
    end
  end)
end

function Info:exit(callback)
  callback()
end

function Info:getType()
  return 'AUTOUPDATES'
end

return Info
