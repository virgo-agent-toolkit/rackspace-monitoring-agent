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
local HostInfo = require('./base').HostInfo

local table = require('table')
local execFileToBuffers = require('./misc').execFileToBuffers
local los = require('los')
local sigar = require('sigar')
local fmt = require('string').format

--[[ Check CVE fixes ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  if los.type() ~= 'linux' then
    self._error = 'Unsupported OS for pluggable auth module definitions'
    return callback()
  end

  local vendor, cmd, args, opts, cves

  vendor = sigar:new():sysinfo().vendor:lower()
  cmd = 'sh'
  if vendor == 'ubuntu' or vendor == 'debian' then
    args = {'-c',  'zcat /usr/share/doc/*/changelog.Debian.gz | grep CVE-'}
  elseif vendor == 'rhel' or vendor == 'centos' then
    args = {'-c', 'rpm -qa --changelog | grep CVE-'}
  else
    self._error = 'Could not determine linux distro for Packages'
    return callback()
  end
  opts = {}
  cves = {}

  local function execCb(err, exitcode, stdout_data, stderr_data)
    if exitcode ~= 0 then
      self._error = fmt("Vulnerabilities check exited with a %d exitcode", exitcode)
      return callback()
    end
    for line in stdout_data:gmatch("[^\r\n]+") do
      local cvestart, cveend = line:find('CVE-')
      local cvestr = line:sub(cvestart, cvestart+12)
      -- we want unique cves only
      cves[cvestr] = 1
    end
    for key, val in pairs(cves) do
      table.insert(self._params, key)
    end
    table.sort(self._params)
    return callback()
  end

  return execFileToBuffers(cmd, args, opts, execCb)
end

function Info:getType()
  return 'CVE'
end

return Info
