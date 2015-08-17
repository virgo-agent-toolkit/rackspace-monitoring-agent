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
local readCast = require('./misc').readCast

--[[ Check fstab ]]--
local HostInfo = require('./base').HostInfo
local Info = HostInfo:extend()

function Info:run(callback)
  local filename = '/etc/fstab'
  local obj = {}

  local function casterFunc(iter, line)
    local types = {'file_system', 'mount_point', 'type', 'options', 'pass' }
    for i = 1, #types do
      obj[types[i]] = iter()
    end
  end

  local function cb(err)
    self:_pushParams(err, obj)
    return callback()
  end

  readCast(filename, casterFunc, cb)
end

function Info:getPlatforms()
  return {'linux'}
end

function Info:getType()
  return 'FSTAB'
end

return Info
