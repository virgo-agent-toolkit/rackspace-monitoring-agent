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
local run = require('./misc').run
local Transform = require('stream').Transform

--------------------------------------------------------------------------------------------------------------------
local Reader = Transform:extend()

function Reader:initialize()
  Transform.initialize(self, {objectMode = true})
end

function Reader:_transform(line, cb)
  local begins, dataTable = {}, {}
  local function getLoginTime(dataTable)
    local str = {}
    for i = 4, 7 do
      table.insert(str, dataTable[i])
    end
    return table.concat(str, ' ')
  end

  line:gsub("%S+", function(c) table.insert(dataTable, c) end)

  if dataTable[2] == 'system' and dataTable[3] == 'boot' then
    self:push({bootups = {
      type = dataTable[1],
      kernel = dataTable[4]
    }})
  elseif dataTable[8] == 'still' then
    self:push({logged_in = {
      user = dataTable[1],
      host = dataTable[3],
      login_time = getLoginTime(dataTable)
    }})
  elseif dataTable[1] == 'wtmp' then
    for i = 3, 7 do
      table.insert(begins, dataTable[i])
    end
    self:push({data_collection_start = table.concat(begins, ' ')})
  elseif #line > 0 then
    self:push({previous_logins = {
      user = dataTable[1],
      host = dataTable[3],
      login_time = getLoginTime(dataTable),
      logout_time = dataTable[9],
      duration = dataTable[10]:match('%((.+)%)')
    }})
  end
  cb()
end
--------------------------------------------------------------------------------------------------------------------
--[[ Last logins ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  local outTable, errTable = {}, {}
  local cmd, args = 'last', {}

  local function finalCb()
    self:_pushParams(errTable, outTable)
    return callback()
  end

  local child = run(cmd, args)
  local reader = Reader:new()
  child:pipe(reader)
  reader:on('data', function(data)
    for k, v in pairs(data) do
      if type(v) == 'string' then outTable[k] = v
      elseif type(v) == 'table' then
        if not outTable[k] then outTable[k] = {} end
        table.insert(outTable[k], v)
      end
    end
  end)
  reader:on('error', function(data) table.insert(errTable, data) end)
  reader:once('end', function()
    if outTable.data_collection_start and outTable.bootups then
      if #outTable.bootups == 1 then
        outTable.bootups[1]['when'] = outTable.data_collection_start
      end
    end
    finalCb()
  end)
end

function Info:getPlatforms()
  return {'linux'}
end

function Info:getType()
  return 'LAST_LOGINS'
end

exports.Info = Info
exports.Reader = Reader
