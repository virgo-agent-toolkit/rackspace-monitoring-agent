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
local logWarn = require('./misc').logWarn
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
    local function getDeps(dependencies)
      local dependsArr = {}
      for word in dependencies:gmatch('([^,]+)') do
        table.insert(dependsArr, word)
      end
      return dependsArr
    end

    table.insert(obj, {
      name = iter(),
      mem_size = iter(),
      instanceCount = iter(),
      dependencies = getDeps(iter()),
      state = iter(),
      memOffset = iter(),
      depends = iter()
    })
  end

  local function cb()
    if errTable and next(errTable) then
      if not self._params or not next(self._params) then
        self._error = errTable
      else
        logWarn(errTable)
      end
    end
    return callback()
  end

  readCast(filename, errTable, self._params, casterFunc, cb)
end

function Info:getType()
  return 'KERNEL_MODULES'
end

return Info
