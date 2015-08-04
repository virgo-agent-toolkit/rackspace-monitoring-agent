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

--[[ iptables ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:run(callback)
  if los.type() ~= 'linux' then
    self._error = 'Unsupported OS for last logins'
    return callback()
  end

  local function execCb(err, exitcode, stdout_data, stderr_data)
    if exitcode ~= 0 then
      self._error = fmt("Command 'last' exited with a %d exitcode.", exitcode)
      return callback()
    end

    local chain, type, iter
    for line in stdout_data:gmatch("[^\r\n]+") do
      local dataTable = {}
      iter = line:gmatch("%S+")
      type = iter()
      if type == '-P' then
        table.insert(dataTable, {
          type = type,
          chain = iter(),
          policy = iter()
        })
      elseif type == '-N' then
        table.insert(dataTable, {
          type = type,
          chain = iter()
        })
      elseif type == '-A' then
        chain = iter()
        table.insert(dataTable, {
          type = type,
          chain = chain,
          policy = line:sub(line:find(chain))
        })
      end
    end

    table.insert(self._params, dataTable)
    return callback()
  end

  return execFileToBuffers('ip6tables', {'-S'}, {}, execCb)
end

function Info:getType()
  return 'IP6TABLES'
end

return Info
