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
local Object = require('core').Object
local JSON = require('json')

local fs = require('fs')
local misc = require('/base/util/misc')
local os = require('os')

local asserts = require('bourbon').asserts

local classes = require('./all')

local function create_map()
  local map = {}
  for x, klass in pairs(classes) do
    asserts.ok(klass.getType and klass.getType(), "HostInfo getType() undefined or returning nil: " .. tostring(x))
    map[klass.getType()] = klass
  end
  return map
end

local HOST_INFO_MAP = create_map()

--[[ Factory ]]--
local function create(infoType)
  local klass = HOST_INFO_MAP[infoType]
  if klass then
    return klass:new()
  end
  return NilInfo:new()
end

-- Dump all the info objects to a file
local function debugInfo(fileName, callback)
  local data = ''
  for k, v in pairs(HOST_INFO_MAP) do
    local info = create(v)
    local obj = info:serialize().metrics
    data = data .. '-- ' .. v .. '.' .. os.type() .. ' --\n\n'
    data = data .. misc.toString(obj)
    data = data .. '\n'
  end
  fs.writeFile(fileName, data, callback)
end

--[[ Exports ]]--
local exports = {}
exports.create = create
exports.debugInfo = debugInfo
exports.classes = classes
return exports
