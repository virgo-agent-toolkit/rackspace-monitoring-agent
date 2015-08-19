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
local execFileToBuffers = require('./misc').execFileToBuffers
local los = require('los')
local string = require('string')

--[[ SSHd Variables ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  if los.type() == 'win32' then
    self._error = 'Unsupported OS for sshd'
    return callback()
  end

  local function execCb(err, exitcode, stdout_data, stderr_data)
    if exitcode ~= 0 then
      self._error = string.format("SSHD exited with a %d exitcode", exitcode)
      return callback()
    end
    for line in stdout_data:gmatch("[^\r\n]+") do
      line = line:gsub("^%s*(.-)%s*$", "%1")
      local _, _, key, value = line:find("(.*)%s(.*)")
      if key ~= nil then
        local obj = {}
        obj[key] = value
        table.insert(self._params, obj)
      end
    end
    callback()
  end

  local command = '/usr/sbin/sshd'
  local args = {'-T'}
  local options = {}

  execFileToBuffers(command, args, options, execCb)

end

function Info:getType()
  return 'SSHD'
end

return Info
