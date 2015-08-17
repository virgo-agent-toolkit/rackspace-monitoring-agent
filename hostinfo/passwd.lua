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
local fs = require('fs')
local misc = require('./misc')
local filename = '/etc/passwd'
local tts = require('virgo/util/misc').tableToString

--[[ Passwordstatus Variables ]]--
local Info = HostInfo:extend()

-- Hostinfo check
function Info:run(callback)
  local data, err, object, users
  object, users = {}, {}

  -- Create list of users we want to retrieve passwd info for
  data, err = fs.readFileSync(filename)

  if err then
    self._error = "Couldn't read /etc/passwd"
    return callback()
  end
  for line in data:gmatch("[^\r\n]+") do
    local name = line:match("[^:]*")
    table.insert(users, name)
  end

  ---- Utility funcs
  local function spawnFunc(datum)
    local cmd = 'passwd'
    local args = {'-S', datum}
    return cmd, args
  end
  exports.spawnFunc = spawnFunc

  local function onLineFunc(data, datum)
    -- data is current line, datum is entry in the list were on
    if data ~= nil and data ~= '' then
      data = data:gsub('[\n|"]','')
      local iter = data:gmatch("%S+")
      table.insert(object, {
        username = iter(),
        status = iter(),
        last_changed = iter(),
        minimum_age = iter(),
        warning_period = iter(),
        inactivity_period = iter()
      })
    end
  end
  exports.onLineFunc = onLineFunc

  local function finalCb(errData)
    self:_pushParams(errData, object)
    return callback()
  end

  return misc.asyncSpawn(users, spawnFunc, onLineFunc, finalCb)
end

function Info:getPlatforms()
  return {'linux'}
end

function Info:getType()
  return 'PASSWD'
end

exports.Info = Info