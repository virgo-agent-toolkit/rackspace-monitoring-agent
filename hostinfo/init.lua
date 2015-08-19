--[[
Copyright 2014 Rackspace

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
local table = require('table')

local fs = require('fs')
local misc = require('virgo/util/misc')
local los = require('los')
local async = require('async')

local HostInfo = require('./base').HostInfo
local classes = require('./all')

local function create_class_info()
  local map = {}
  local types = {}
  for x, klass in pairs(classes) do
    if klass.Info then klass = klass.Info end
    map[klass.getType()] = klass
    table.insert(types, klass.getType())
  end
  return {map = map, types = types}
end

local CLASS_INFO = create_class_info()
local HOST_INFO_MAP = CLASS_INFO.map
local HOST_INFO_TYPES = CLASS_INFO.types

--[[ NilInfo ]]--
local NilInfo = HostInfo:extend()
function NilInfo:initialize()
  HostInfo.initialize(self)
  self._error = 'Agent does not support this Host Info type'
end

--[[ Factory ]]--
local function create(infoType)
  local klass = HOST_INFO_MAP[infoType]
  if klass then
    if klass.Info then
      return klass.Info:new()
    else
      return klass:new()
    end
  end
  return NilInfo:new()
end

-- [[ Types ]]--
local function getTypes()
  return HOST_INFO_TYPES
end

-- Dump all the info objects to a file
local function debugInfo(fileName, callback)
  local data = ''
  async.forEachLimit(HOST_INFO_TYPES, 5, function(v, cb)
    local klass = create(v)
    klass:run(function(err)
      local obj = klass:serialize()
      data = data .. '-- ' .. v .. '.' .. los.type() .. ' --\n\n'
      data = data .. misc.toString(obj)
      data = data .. '\n'
      cb()
    end)
  end, function()
    fs.writeFile(fileName, data, callback)
  end)
end

--[[ Exports ]]--
local exports = {}
exports.create = create
exports.debugInfo = debugInfo
exports.classes = classes
exports.getTypes = getTypes
return exports
