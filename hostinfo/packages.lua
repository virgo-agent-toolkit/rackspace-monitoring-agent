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
local os = require('os')
local sctx = require('../sigar').ctx
local spawn = require('childprocess').spawn
local table = require('table')

--[[ Packages Variables ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:run(callback)
  if os.type() ~= 'Linux' then
    self._error = 'Unsupported OS for Packages'
    callback()
    return
  end

  local sysinfo = sctx:sysinfo()
  local package_cmd = ''
  local child = ''
  local vendor = sysinfo.vendor:lower()

  if vendor == 'ubuntu' or vendor == 'debian' then
    package_cmd = 'dpkg-query'
    child = spawn('dpkg-query', {'-W'}, {})
  elseif vendor == 'rhel' or vendor == 'centos' then
    package_cmd = 'rpm'
    child = spawn('rpm', {"-qa", '--queryformat', '%{NAME}: %{VERSION}-%{RELEASE}\n'}, {})
  else
    self._error = 'Could not determine OS for Packages'
    callback()
    return
  end

  local data = ''

  child.stdout:on('data', function(chunk)
    data = data .. chunk
  end)

  child:on('exit', function(exit_code)
    if exit_code ~= 0 then
      self._error = fmt("Packages exited with a %d exit_code", exit_code)
      callback()
      return
    end
    local line
    for line in data:gmatch("[^\r\n]+") do
      line = line:gsub("^%s*(.-)%s*$", "%1")
      local a, b, key, value = line:find("(.*)%s(.*)")
      if key ~= nil then
        local obj = {}
        obj[key] = value
        table.insert(self._params, obj)
      end
    end
    callback()
  end)

  child:on('error', function(err)
    self._error = err
    callback()
  end)
end

function Info:getType()
  return 'PACKAGES'
end

return Info
