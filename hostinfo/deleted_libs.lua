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
local table = require('table')
local los = require('los')
local execFileToBuffers = require('./misc').execFileToBuffers
local fmt = require('string').fmt

--[[ Any services/processes using deleted libraries? ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  if los.type() ~= 'linux' then
    self._error = 'Unsupported OS for deleted libraries check'
    return callback()
  end
  local cmd = 'lsof'
  local args = {'-nnP' }
  local out = {}

  local function execCb(err, exitcode, stdout_data, stderr_data)
    if exitcode ~= 0 then
      self._error = fmt("lsof -nnP exited with a %d exitcode", exitcode)
      return callback()
    end
    for line in stdout_data:gmatch("[^\r\n]+") do
      local dataTable = {}
      if line ~= nil and line ~= '' then
        line:gsub('%S+', function(word) table.insert(dataTable, word) end)
      end
      if dataTable[4] == 'DEL' then
        table.insert(out, {
          used_by_process = dataTable[1],
          deleted_lib_name = dataTable[8]
        })
      end
    end
    if not next(out) then
      table.insert(self._params, 'No services using deleted libraries found')
    else
      table.insert(self._params, out)
    end
    return callback()
  end

  return execFileToBuffers(cmd, args, {}, execCb)
end

function Info:getType()
  return 'DELETED_LIBS'
end

return Info
