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

local los = require('los')

local Object = require('core').Object
local gmtNow = require('virgo/utils').gmtNow
local tableToString = require('virgo/util/misc').tableToString

-------------------------------------------------------------------------------

local HostInfo = Object:extend()
function HostInfo:initialize()
  self._params = {}
  self._error = nil
end

function HostInfo:serialize()
  return {
    error = self._error,
    metrics = self._params,
    timestamp = gmtNow()
  }
end

function HostInfo:run(callback)
  callback()
end

function HostInfo:getRestrictedPlatforms()
  return {}
end

function HostInfo:isRestrictedPlatform()
  local currentPlatform = los.type()
  for _, platform in pairs(self:getRestrictedPlatforms()) do
    if platform == currentPlatform then
      self._error = 'unsupported operating system for ' .. self:getType()
      return true
    end
  end
  return false
end


function HostInfo:pushParams(obj, err)
  if not obj or not next(obj) then
    if type(err) == 'string' then
      self._error = err
    else
      self._error = tableToString(err)
    end
  else
    self._params = obj
  end
end

exports.HostInfo = HostInfo