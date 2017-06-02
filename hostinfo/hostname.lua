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
local misc = require('virgo/util/misc')
local Transform = require('stream').Transform

--------------------------------------------------------------------------------------------------------------------
local Reader = Transform:extend()
function Reader:initialize()
  Transform.initialize(self, {objectMode = true})
end

function Reader:_transform(line, cb)
  self:push({hostname = line})
  return cb()
end
--------------------------------------------------------------------------------------------------------------------

--[[ Fetch this servers hostname ]]--
local Info = HostInfo:extend()
function Info:initialize(params)
  HostInfo.initialize(self)
end

function Info:_run(callback)
  local command = 'hostname'
  local outTable, errTable = {}, {}

  local function finalCb()
    self:_pushParams(errTable, outTable)
    return callback()
  end

  local child = misc.run('sh', {'-c', command})
  local reader = Reader:new()
  child:pipe(reader)
  reader:on('error', function(err) misc.safeMerge(errTable, err) end)
  reader:on('data', function(datum) misc.safeMerge(outTable, datum) end)
  reader:once('end', finalCb)
end

function Info:getPlatforms()
  return {'linux'}
end

function Info:getType()
  return 'HOSTNAME'
end

exports.Info = Info
exports.Reader = Reader
