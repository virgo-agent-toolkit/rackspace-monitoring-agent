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
]]--
local HostInfo = require('./base').HostInfo
local read = require('virgo/util/misc').read
local Transform = require('stream').Transform
--------------------------------------------------------------------------------------------------------------------
local Reader = Transform:extend()
function Reader:initialize()
  Transform.initialize(self, {objectMode = true})
end

function Reader:_transform(line, cb)
  local out = {}
  local iter = line:gmatch("%S+")
  local types = {'file_system', 'mount_point', 'type', 'options', 'pass' }
  for i = 1, #types do
    out[types[i]] = iter()
  end
  self:push(out)
  return cb()
end
--------------------------------------------------------------------------------------------------------------------

--[[ Check fstab ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  local filename = '/etc/fstab'
  local ouTable, errTable = {}, {}

  local function finalCb()
    self:_pushParams(errTable, ouTable)
    return callback()
  end

  local readStream = read(filename)
  local reader = Reader:new()
  -- Catch no file found errors
  readStream:on('error', function(err)
    table.insert(errTable, err)
    return finalCb()
  end)
  readStream:pipe(reader)
  reader:on('data', function(data) table.insert(ouTable, data) end)
  reader:on('error', function(err) table.insert(errTable, err) end)
  reader:once('end', finalCb)
end

function Info:getPlatforms()
  return {'linux'}
end

function Info:getType()
  return 'FSTAB'
end

exports.Info = Info
exports.Reader = Reader