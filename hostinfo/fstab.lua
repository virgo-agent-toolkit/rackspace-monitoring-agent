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
]]--
local los = require('los')
local readCast = require('./misc').readCast

--[[ Check fstab ]]--
local HostInfo = require('./base').HostInfo
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:run(callback)
  local function casterFunc(iter, obj)
    local types = {'file_system', 'mount_point', 'type', 'options', 'pass' }
    for i = 1, #types do
      obj[types[i]] = iter()
    end
  end

  if los.type() ~= 'linux' then
    self._error = 'Unsupported OS for file permissions'
    return callback()
  end

  readCast('/etc/fstab', self._error, self._params, casterFunc, callback)
end

function Info:getType()
  return 'FSTAB'
end

return Info
