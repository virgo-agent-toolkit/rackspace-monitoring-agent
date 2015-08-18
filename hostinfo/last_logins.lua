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

local fmt = require('string').format
local los = require('los')
local table = require('table')
local execFileToBuffers = require('./misc').execFileToBuffers

--[[ Last logins ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  if los.type() ~= 'linux' then
    self._error = 'Unsupported OS for last logins'
    return callback()
  end

  local function execCb(err, exitcode, stdout_data, stderr_data)
    if exitcode ~= 0 then
      self._error = fmt("Command 'last' exited with a %d exitcode.", exitcode)
      return callback()
    end
    local function getLoginTime(dataTable)
      local str = {}
      for i = 4, 7 do
        table.insert(str, dataTable[i])
      end
      return table.concat(str, ' ')
    end
    local bootups = {}
    local logged_in = {}
    local previous_logins = {}
    local begins = {}
    for line in stdout_data:gmatch("[^\r\n]+") do
      local dataTable = {}
      line:gsub("%S+", function(c) table.insert(dataTable, c) end)
      if dataTable[2] == 'system' and dataTable[3] == 'boot' then
        table.insert(bootups, {
          type = dataTable[1],
          kernel = dataTable[4]
        })
      elseif dataTable[8] == 'still' then
        table.insert(logged_in, {
          user = dataTable[1],
          host = dataTable[3],
          login_time = getLoginTime(dataTable)
        })
      elseif dataTable[1] == 'wtmp' then
        for i = 3, 7 do
          table.insert(begins, dataTable[i])
        end
        begins = table.concat(begins, ' ')
      else
        table.insert(previous_logins, {
          user = dataTable[1],
          host = dataTable[3],
          login_time = getLoginTime(dataTable),
          logout_time = dataTable[9],
          duration = dataTable[10]
        })
      end
    end
    table.insert(self._params, {
      bootups = bootups,
      logged_in = logged_in,
      previous_logins = previous_logins,
      data_collection_start = begins
    })
    return callback()
  end

  return execFileToBuffers('last', {}, {}, execCb)
end

function Info:getType()
  return 'LAST_LOGINS'
end

return Info
