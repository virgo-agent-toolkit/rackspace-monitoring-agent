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
  local iter = line:gmatch("%S+")
  local type = iter()
  if type == '-P' then
    self:push({type = type, chain = iter(), policy = iter()})
  elseif type == '-N' then
    self:push({type = type, chain = iter()})
  elseif type == '-A' then
    local policy = ''
    local chain = iter()
    local idx = line:find(chain)
    if idx then policy = line:sub(idx) end
    self:push({type = type, chain = chain, policy = policy})
  end
  cb()
end
--------------------------------------------------------------------------------------------------------------------
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  local errTable, outTable = {}, {}
  local cmd, args = 'ip6tables', {'-S'}

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
  return 'IP6TABLES'
end

exports.Info = Info
exports.Reader = Reader

