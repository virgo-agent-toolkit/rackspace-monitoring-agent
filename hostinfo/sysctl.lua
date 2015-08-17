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

local Info = HostInfoStdoutSubProc:extend()
function Info:initialize()
  HostInfoStdoutSubProc.initialize(self, 'sysctl', {'-A'})
end

function Info:_transform(line, callback)
  line = line:gsub("^%s*(.-)%s*$", "%1")
  local _, _, key, value = line:find("([^=^%s]+)%s*=%s*([^=]*)")
  if key and value then
    self:push({ [key] = value })
  end
  callback()
end

function Info:getPlatforms()
  return {'linux', 'darwin', 'freebsd', 'openbsd', 'netbsd'}
end

function Info:getType()
  return 'SYSCTL'
end

return Info
