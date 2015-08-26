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
local read = require('./misc').read
local Transform = require('stream').Transform

--------------------------------------------------------------------------------------------------------------------
local Reader = Transform:extend()
function Reader:initialize()
  Transform.initialize(self, {objectMode = true})
end

function Reader:_transform(line, cb)
  local function getDeps(dependsArr)
    local outobj = {}
    for word in dependsArr:gmatch('([^,]+)') do
      table.insert(outobj, word)
    end
    return outobj
  end
  local iter = line:gmatch("%S+")

  self:push({
    name = iter(),
    mem_size = iter(),
    instanceCount = iter(),
    dependencies = getDeps(iter()),
    state = iter(),
    memOffset = iter(),
  })
  return cb()
end
--------------------------------------------------------------------------------------------------------------------

--[[ Kernel modules ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  local filename = "/proc/modules"
  local outTable, errTable = {}, {}

  local function finalCb()
    self:_pushParams(errTable, outTable)
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
  reader:on('data', function(data) table.insert(outTable, data) end)
  reader:on('error', function(err) table.insert(errTable, err) end)
  reader:once('end', finalCb)
end

function Info:getPlatforms()
  return {'linux'}
end

function Info:getType()
  return 'KERNEL_MODULES'
end

exports.Info = Info
exports.Reader = Reader
