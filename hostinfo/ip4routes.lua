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
local misc = require('./misc')

-------------------------------------------------------------------------------

local Info = HostInfoStdoutSubProc:extend()
function Info:initialize(command, args)
  HostInfoStdoutSubProc.initialize(self, command, args)
end

function Info:_transform(line, callback)
  local iter = line:gmatch("%S+")
  local firstw = iter()
  if firstw ~= 'Destination' and firstw ~= 'Kernel' then
    self:push({
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
  callback()
end

function Info:getPlatforms()
  return {'linux'}
end

function Info:getType()
  return 'IP4ROUTES'
end

-------------------------------------------------------------------------------

local DebInfo = Info:extend()
function DebInfo:initialize()
  Info.initialize(self, 'netstat', {'-nr4'})
end

-------------------------------------------------------------------------------

local RpmInfo = Info:extend()
function RpmInfo:initialize()
  Info.initialize(self, 'netstat', {'-nr'})
end

return misc.getInfoByVendor({
  centos = RpmInfo,
  rhel   = RpmInfo,
  ubuntu = DebInfo,
  debian = DebInfo,
  default = DebInfo
})
