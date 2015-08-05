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

local HostInfoStdoutSubProc = require('./base').HostInfoStdoutSubProc
local MetricsHandler = require('./base').MetricsHandler
local sigar = require('sigar')

-------------------------------------------------------------------------------

local Handler = MetricsHandler:extend()
function Handler:initialize()
  MetricsHandler.initialize(self)
end

function Handler:_transform(line, callback)
  local iter = line:gmatch("%S+")
  local firstw = iter()
  if firstw ~= 'Destination' and firstw ~= 'Kernel' then
    self:push({
      destination = firstw,
      next_hop = iter(),
      flags = iter(),
      metric = iter(),
      ref = iter(),
      use = iter(),
      iface = iter()
    })
  end
  callback()
end

-------------------------------------------------------------------------------

local Info = HostInfoStdoutSubProc:extend()
function Info:initialize()
  local command = 'netstat'
  local args = {'-nr6'}
  local vendor = sigar:new():sysinfo().vendor:lower()
  if vendor == 'ubuntu' or vendor == 'debian' then
    args = {'-nr6'}
  elseif vendor == 'rhel' or vendor == 'centos' then
    args = {'-nr', '--inet6'}
  end
  HostInfoStdoutSubProc.initialize(self, command, args, Handler:new())
end

function Info:getRestrictedPlatforms()
  return {'win32', 'darwin'}
end

function Info:getType()
  return 'IP6ROUTES'
end

return Info
