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

local readCast = require('./misc').readCast

--[[ Login ]]--
local Info = HostInfo:extend()

function Info:run(callback)
  local filename = "/etc/login.defs"
  local obj = {}

  local function casterFunc(iter, line)
    local key = iter()
    local val = iter()
    obj[key] = val
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
  return 'LOGIN'
end

return Info
