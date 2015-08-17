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
local readCast = require('./misc').readCast

--[[ Kernel modules ]]--
local Info = HostInfo:extend()

function Info:run(callback)
  local filename = "/proc/modules"
  local obj = {}

  local function casterFunc(iter, line)
    local function getDeps(dependsArr)
      local outobj = {}
      for word in dependsArr:gmatch('([^,]+)') do
        table.insert(outobj, word)
      end
      return outobj
    end

    table.insert(obj, {
      name = iter(),
      mem_size = iter(),
      instanceCount = iter(),
      dependencies = getDeps(iter()),
      state = iter(),
      memOffset = iter(),
    })
  end

  local function cb(err)
    self:_pushParams(err, obj)
    return callback()
  end

  return readCast(filename, casterFunc, cb)
end

function Info:getPlatforms()
  return {'linux'}
end

function Info:getType()
  return 'KERNEL_MODULES'
end

return Info
