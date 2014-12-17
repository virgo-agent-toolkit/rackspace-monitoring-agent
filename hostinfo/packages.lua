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
local table = require('table')
local execFileToBuffers = require('./misc').execFileToBuffers

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

  local function execCb(err, exitcode, stdout_data, stderr_data)
    if exitcode ~= 0 then
      self._error = fmt("Packages exited with a %d exitcode", exitcode)
      callback()
      return
    end
    local line
    for line in stdout_data:gmatch("[^\r\n]+") do
      line = line:gsub("^%s*(.-)%s*$", "%1")
      local a, b, key, value = line:find("(.*)%s(.*)")
      if key ~= nil then
        local obj = {}
        obj[key] = value
        table.insert(self._params, obj)
      end
    end
    callback()
  end

  local sysinfo = sctx:sysinfo()
  local vendor = sysinfo.vendor:lower()
  local command = ''
  local args = {}
  local options = {}

  if vendor == 'ubuntu' or vendor == 'debian' then
    command = 'dpkg-query'
    args = {'-W'}
    options = {}
  elseif vendor == 'rhel' or vendor == 'centos' then
    command = 'rpm'
    args = {"-qa", '--queryformat', '%{NAME}: %{VERSION}-%{RELEASE}\n'}
    options = {}
  else
    self._error = 'Could not determine OS for Packages'
    callback()
    return
  end

  execFileToBuffers(command, args, options, execCb)
end

function Info:getType()
  return 'PACKAGES'
end

return Info
