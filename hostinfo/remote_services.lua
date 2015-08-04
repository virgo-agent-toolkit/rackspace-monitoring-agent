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

--[[ remote services check]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:run(callback)
  if los.type() ~= 'linux' then
    self._error = 'Unsupported OS for remote services'
    return callback()
  end

  local cmd, args, opts
  opts = {}
  cmd = 'netstat'
  args = {'-tlpen'}


  local function execCB(err, exitcode, stdout_data, stderr_data)
    if exitcode ~= 0 then
      self._error = fmt("netstat exited with a %d exitcode", exitcode)
      return callback()
    end

    local function getpidandpname(str)
      if not str or #str == 1 then
        return '-', '-'
      else
        return str:sub(1, str:find('%/')-1), str:sub(str:find('%/')+1)
      end

    end
    for line in stdout_data:gmatch("[^\r\n]+") do
      local iter = line:gmatch("%S+")
      local firstw = iter()
      if firstw == '(Not' or firstw == 'Active' or firstw == 'Proto' or firstw == 'will' then
        -- Do nothing
      else
        local obj = {
          protocol = firstw,
          recvq = iter(),
          sendq = iter(),
          local_addr = iter(),
          foreign_addr = iter(),
          state = iter(),
          user = iter(),
          inode = iter()
        }
        obj.pid, obj.proccess = getpidandpname(iter())
        table.insert(self._params, obj)
      end
    end
    return callback()
  end
  return execFileToBuffers(cmd, args, opts, execCB)
end

function Info:getType()
  return 'REMOTE_SERVICES'
end

return Info
