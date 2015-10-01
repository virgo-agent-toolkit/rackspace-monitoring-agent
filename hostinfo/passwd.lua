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
local async = require('async')
local fs = require('fs')
local Transform = require('stream').Transform
local run = require('./misc').run

local PASSWD_PATH = '/etc/passwd'
local CONCURRENCY = 5
--[[ Passwordstatus Variables ]]--

--------------------------------------------------------------------------------------------------------------------
local Reader = Transform:extend()
function Reader:initialize()
  Transform.initialize(self, {objectMode = true})
end

function Reader:_transform(data, callback)
  if data and #data > 0 then
    data = data:gsub('[\n|"]','')
    local iter = data:gmatch("%S+")
    self:push({
      name = iter(),
      status = iter(),
      last_changed = iter(),
      minimum_age = iter(),
      warning_period = iter(),
      inactivity_period = iter()
    })
  end
  return callback()
end
--------------------------------------------------------------------------------------------------------------------
local Info = HostInfo:extend()

function Info:_run(callback)
  local errTable, outTable = {}, {}
  fs.readFile(PASSWD_PATH, function(err, data)
    if err then
      self:_pushError("Couldn't read /etc/passwd")
      return callback()
    end

    local users = {}

    for line in data:gmatch("[^\r\n]+") do
      local name = line:match("[^:]*")
      table.insert(users, name)
    end

    local function iter(datum, callback)
      local cmd, args = 'passwd', {'-S', datum}
      local child = run(cmd, args)
      local reader = Reader:new()
      child:pipe(reader)
      reader:on('data', function(data) table.insert(outTable, data) end)
      reader:on('error', function(data) table.insert(errTable, data) end)
      reader:once('end', callback)
    end

    local function finalCb()
      self:_pushParams(errTable, outTable)
      return callback()
    end

    async.forEachLimit(users, CONCURRENCY, iter, finalCb)
  end)
end

function Info:getType()
  return 'PASSWD'
end

exports.Info = Info
exports.Reader = Reader