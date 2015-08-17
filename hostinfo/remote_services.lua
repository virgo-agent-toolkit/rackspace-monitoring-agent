
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

local HostInfoStdoutSubProc = require('./base').HostInfoStdoutSubProc

local function getpidandpname(str)
  if not str or #str == 1 then
    return '-', '-'
  else
    return str:sub(1, str:find('%/')-1), str:sub(str:find('%/')+1)
  end
end

local Info = HostInfoStdoutSubProc:extend()
function Info:initialize()
  HostInfoStdoutSubProc.initialize(self, 'netstat', {'-tlpen'})
end

function Info:_transform(line, callback)
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
    self:push(obj)
  end
  callback()
end

function Info:getPlatforms()
  return {'linux'}
end

function Info:getType()
  return 'REMOTE_SERVICES'
end

return Info
