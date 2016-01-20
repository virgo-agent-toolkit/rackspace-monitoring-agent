
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

local HostInfo = require('./base').HostInfo
local run = require('virgo/util/misc').run
local Transform = require('stream').Transform

--------------------------------------------------------------------------------------------------------------------
local Reader = Transform:extend()

function Reader:initialize()
  Transform.initialize(self, {objectMode = true})
end

function Reader:_transform(line, cb)
  local function getpidandpname(str)
    if not str or #str == 1 then
      return '-', '-'
    else
      return str:sub(1, str:find('%/')-1), str:sub(str:find('%/')+1)
    end
  end
  local iter = line:gmatch("%S+")
  local firstw = iter()
  if firstw ~= '(Not' and firstw ~= 'Active' and firstw ~= 'Proto' and firstw ~= 'will' then
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
  cb()
end
--------------------------------------------------------------------------------------------------------------------
local Info = HostInfo:extend()

function Info:_run(callback)
  local cmd, args = 'netstat', {'-tlpen'}
  local outTable, errTable = {}, {}

  local function finalCb()
    self:_pushParams(errTable, outTable)
    return callback()
  end

  local child = run(cmd, args)
  local reader = Reader:new()
  child:pipe(reader)
  reader:on('data', function(data) table.insert(outTable, data) end)
  reader:on('error', function(data) table.insert(errTable, data) end)
  reader:once('end', finalCb)
end

function Info:getPlatforms()
  return {'linux'}
end

function Info:getType()
  return 'REMOTE_SERVICES'
end

exports.Info = Info
exports.Reader = Reader