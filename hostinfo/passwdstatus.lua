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

local forEachLimit = require('async').forEachLimit
local os = require('os')
local spawn = require('childprocess').spawn
local table = require('table')

--[[ Passwordstatus Variables ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:run(callback)
  if os.type() ~= 'Linux' then
    self._error = 'Unsupported OS for passwdstatus'
    callback()
    return
  end

  function collectData(users)
    --[[ Asynchronous gather user passwd info ]]--
    local obj = {}

    forEachLimit(users, 5, function(user, callback)
      local child
      child = spawn('passwd', {'-S', user}, {})

      local data = ''
      child.stdout:on('data', function(chunk)
        data = data .. chunk
      end)

      local errdata = ''
      child.stderr:on('data', function(chunk)
        errdata = errdata .. chunk
      end)

      child:on('error', function(err)
        errdata = err
      end)

      child:on('exit', function(exit_code)
        if exit_code ~= 0 then
          return
        end
      end)

      child.stdout:on('end', function()
        if data ~= nil and data ~= '' then
          data = data:gsub('[\n|"]','')
          t = {}
          --[[ Split string into table by spaces. ]]--
          data:gsub("%S+", function(c) table.insert(t,c) end)
          obj[user] = {
            ['status'] = t[2],
            ['last_changed'] = t[3],
            ['minimum_age'] = t[4],
            ['warning_period'] = t[5],
            ['inactivity_period'] = t[6],
          }
        end
        if errdata ~= nil and errdata ~= '' then
          obj[user] = errdata:gsub('[\n|"]','')
        end
        callback()
      end)
    end, function()
      table.insert(self._params, obj)
      callback()
    end)
  end

  local passwd
  local users = {}
  local data = ''
  --[[ Probably should replace this with reading the file. ]]
  local passwd = spawn('cat', {'/etc/passwd'}, {})

  passwd.stdout:on('data', function(chunk)
    data = data .. chunk
  end)

  passwd:on('exit', function(exit_code)
    if exit_code ~= 0 then
      return
    end

    local line
    for line in data:gmatch("[^\r\n]+") do
      line = line:match("[^:]*")
      table.insert(users, line)
    end
    -- Call collectData after users table is populated --
    collectData(users)
  end)
end

function Info:getType()
  return 'PASSWDSTATUS'
end

return Info
