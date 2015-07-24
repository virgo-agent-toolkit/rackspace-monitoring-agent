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

local table = require('table')
local los = require('los')
local readCast = require('./misc').readCast

--[[ Kernel modules ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:run(callback)

  if los.type() ~= 'linux' then
    self._error = 'Unsupported OS for Kernel modules'
    return callback()
  end

  local filename = "/proc/modules"
  local errTable = {}

  local function casterFunc(iter, obj)
    local name = iter()
    local mem_size = iter()
    local instanceCount = iter()
    local dependencies = iter()
    local state = iter()
    local memOffset = iter()
    local dependsArr = {}
    for word in dependencies:gmatch('([^,]+)') do
      table.insert(dependsArr, word)
    end
    obj[name] = {
      state = state,
      depends = dependsArr
    }
  end

  local function cb()
    if self._params == nil then
      self._error = errTable
    end
    return callback()
  end

  readCast(filename, errTable, self._params, casterFunc, callback)
end

function Info:getType()
  return 'KERNEL_MODULES'
end

return Info
