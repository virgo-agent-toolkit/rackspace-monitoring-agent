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

function Info:getPlatforms()
  return {'linux', 'darwin'}
end

function Info:getType()
  return 'PACKAGES'
end

function Info:_transform(line, callback)
  line = line:gsub("^%s*(.-)%s*$", "%1")
  local _, _, key, value = line:find("(.*)%s(.*)")
  if key then self:push({ name = key, version = value }) end
  callback()
end

-------------------------------------------------------------------------------

-------------------------------------------------------------------------------

local DebInfo = Info:extend()
function DebInfo:initialize()
  Info.initialize(self, 'dpkg-query', {'-W'})
end

-------------------------------------------------------------------------------

local RpmInfo = Info:extend()
function RpmInfo:initialize()
  Info.initialize(self, 'rpm', {'-qa', '--queryformat', '%{NAME}: %{VERSION}-%{RELEASE}\n' })
end

-------------------------------------------------------------------------------

local BrewInfo = Info:extend()
function BrewInfo:initialize()
  Info.initialize(self, 'brew', {'leaves'})
end

function BrewInfo:_transform(line, callback)
  self:push({ name = line, version = 'unknown' })
  callback()
end

return misc.getInfoByVendor({
  centos = RpmInfo,
  rhel   = RpmInfo,
  ubuntu = DebInfo,
  debian = DebInfo,
  macosx = BrewInfo,
})
