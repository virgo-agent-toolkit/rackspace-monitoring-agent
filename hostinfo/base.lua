--[[
Copyright 2016 Rackspace

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

local gmtNow = require('virgo/utils').gmtNow
local tableToString = require('virgo/util/misc').tableToString
local los = require('los')
local Object = require('core').Object
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

function HostInfo:getType()
  return 'HostInfo'
end

function HostInfo:run(callback)
  if not self:_isValidPlatform() then
    self:_pushError('Unsupported operating system for ' .. self:getType())
    return callback()
  end
  local status, err = pcall(function()
    if self._run then self:_run(callback) else callback() end
  end)
  if not status then
    self._params = {}
    self:_pushError(err)
    callback()
  end
end

function HostInfo:getPlatforms()
  return nil
end

function HostInfo:_isValidPlatform()
  local currentPlatform = los.type()
  -- All platforms are valid if getplatforms isnt defined
  if not self:getPlatforms() then
    return true
  elseif #self:getPlatforms() == 0 then
    return true
  end
  for _, platform in pairs(self:getPlatforms()) do
    if platform == currentPlatform then
      return true
    end
  end
  return false
end

function HostInfo:_pushError(err)
  local undeferr = 'No error specified but no data recieved'
  if type(err) == 'nil' then
    err = undeferr
  elseif type(err) == 'string' then
    if #err == 0 then err = undeferr end
  elseif type(err) == 'number' then
    err = 'Error code:' .. err
  elseif type(err) == 'table' then
    if not next(err) then
      err = undeferr
    else
      err = tableToString(err)
    end
  end
  -- Allow pusherror to be called more than once and additively build errmsgs
  if self._error then
    self._error = '>' .. self._error .. '\n>' .. err
  else
    self._error = err
  end
end

function HostInfo:_pushParams(err, data)
  -- flatten single entry objects
  if type(data) == 'table' then
    if #data == 1 then data = data[1] end
  end
  self._params = data
  if err then
    if type(err) == 'table' and next(err) then
      self:_pushError(err)
    elseif type(err) == 'string' and #err > 0 then
      self:_pushError(err)
    end
  elseif not err and not data or not next(data) then
    self:_pushError(err)
  end
end


exports.HostInfo = HostInfo
