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
local fs = require('fs')
--------------------------------------------------------------------------------------------------------------------

--[[ Read arbitrary files ]]--
local Info = HostInfo:extend()
function Info:initialize(params)
  HostInfo.initialize(self)
  self.params = params
end

function Info:_run(callback)
  if not self.params then
    self:_pushError('ENOENT: You must specify a path to read')
    return callback()
  end

  local name = self.params
  local outTable, errTable = {}, {}

  local function finalCb(err, data)
    misc.safeMerge(errTable, err)
    misc.safeMerge(outTable, data)
    self:_pushParams(errTable, outTable)
    return callback()
  end

  fs.stat(name, function(error, stats)
    if error then
      finalCb(error)
    else
      local type = stats.type
      if type == 'directory' then
        fs.readdir(name, finalCb)
      elseif type == 'file' then
        fs.readFile(name, finalCb)
      end
    end
  end)
end

function Info:getPlatforms()
  return {'linux', 'windows'}
end

function Info:getType()
  return 'READ'
end

exports.Info = Info
