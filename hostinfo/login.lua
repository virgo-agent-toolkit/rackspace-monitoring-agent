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
local misc = require('./misc')
local Transform = require('stream').Transform

--------------------------------------------------------------------------------------------------------------------
local Reader = Transform:extend()
function Reader:initialize()
  Transform.initialize(self, {objectMode = true})
end

function Reader:_transform(line, cb)
  local iter = line:gmatch("%S+")
  local key = iter()
  local val = iter()
  self:push({[key] = val})
  return cb()
end
--------------------------------------------------------------------------------------------------------------------

--[[ Login ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  local filename = "/etc/login.defs"
  local outTable, errTable = {}, {}

  local function finalCb()
    self:_pushParams(errTable, outTable)
    return callback()
  end

  local readStream = misc.read(filename)
  local reader = Reader:new()
  -- Catch no file found errors
  readStream:on('error', function(err)
    misc.safeMerge(errTable, err)
    return finalCb()
  end)
  readStream:pipe(reader)
  reader:on('data', function(data) misc.safeMerge(outTable, data) end)
  reader:on('error', function(err) misc.safeMerge(errTable, err) end)
  reader:once('end', finalCb)
end

function Info:getPlatforms()
  return {'linux'}
end

function Info:getType()
  return 'LOGIN'
end

exports.Info = Info
exports.Reader = Reader