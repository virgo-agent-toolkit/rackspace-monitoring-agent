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

local fmt = require('string').format
local los = require('los')
local sigar = require('sigar')
local table = require('table')
local execFileToBuffers = require('./misc').execFileToBuffers

--[[ IP v4 routes check]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  if los.type() ~= 'linux' then
    self._error = 'Unsupported OS for routs'
    return callback()
  end

  local vendor, cmd, args, method, opts
  vendor = sigar:new():sysinfo().vendor:lower()
  opts = {}
  cmd = 'netstat'

  if vendor == 'ubuntu' or vendor == 'debian' then
    args = {'-nr4'}
  elseif vendor == 'rhel' or vendor == 'centos' then
    args = {'-nr'}
  else
    self._error = 'Could not determine linux distro for ipv4 routes check'
    return callback()
  end

  local function execCB(err, exitcode, stdout_data, stderr_data)
    if exitcode ~= 0 then
      self._error = fmt("netstat exited with a %d exitcode", exitcode)
      return callback()
    end
    for line in stdout_data:gmatch("[^\r\n]+") do
      local iter = line:gmatch("%S+")
      local firstw = iter()
      if firstw == 'Destination' or firstw == 'Kernel' then
        -- Do nothing
      else
        table.insert(self._params, {
          destination = firstw,
          gateway = iter(),
          genmask = iter(),
          flags = iter(),
          mss = iter(),
          window = iter(),
          irtt = iter(),
          iface = iter()
        })
      end
    end
    return callback()
  end
  return execFileToBuffers(cmd, args, opts, execCB)
end

function Info:getType()
  return 'IP4ROUTES'
end

return Info
