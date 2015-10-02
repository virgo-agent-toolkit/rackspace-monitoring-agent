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
  -- Spaces in output come back as \t
  self:push(line:gsub('\t', ' '))
  return cb()
end
--------------------------------------------------------------------------------------------------------------------

--[[ Run arbitrary commands ]]--
local Info = HostInfo:extend()
function Info:initialize(params)
  HostInfo.initialize(self)
  self.params = params
end

function Info:_run(callback)
  if not self.params then
    self:_pushError('ENOENT: You must specify a command to run')
    return callback()
  end

  local command = self.params
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
  return 'RUN'
end

exports.Info = Info
exports.Reader = Reader
