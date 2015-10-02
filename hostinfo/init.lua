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
local fs = require('fs')
local json = require('json')
local los = require('los')
local async = require('async')
local path = require('path')
local HostInfo = require('./base').HostInfo
local classes = require('./all')
local uv = require('uv')

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
local function create(infoType, params)
  local klass = HOST_INFO_MAP[infoType]
  if klass then
    if klass.Info then
      return klass.Info:new(params)
    else
      return klass:new(params)
    end
  end
  return NilInfo:new()
end

-- [[ Types ]]--
local function getTypes()
  return HOST_INFO_TYPES
end

-- [[ Suite of debug util functions ]] --
local function debugInfo(infoType, params, callback)
  if not callback then
    callback = function()
      print('Running hostinfo of type: ' .. infoType)
    end
  end
  local klass = create(infoType, params)
  klass:run(function(err)
    local data = '{"Debug":{"InfoType":"' .. infoType .. '", "OS":"' .. los.type() .. '"}}\n\n'
    if err then
      data = data .. json.stringify({error = err})
    else
      data = data .. json.stringify(klass:serialize(), {indent = 2})
    end
    callback(data)
  end)
end

local function debugInfoAll(callback)
  local data = ''
  async.forEachLimit(HOST_INFO_TYPES, 5, function(infoType, cb)
    debugInfo(infoType, function(debugData)
      data = data .. debugData
      cb()
    end)
  end, function()
    callback(data)
  end)
end

local function debugInfoToFile(infoType, fileName, params, callback)
  debugInfo(infoType, params, function(debugData)
    fs.writeFile(fileName, debugData, callback)
  end)
end

local function debugInfoAllToFile(fileName, callback)
  debugInfoAll(function(data)
    fs.writeFile(fileName, data, callback)
  end)
end

local function debugInfoAllToFolder(folderName, callback)
  fs.mkdirSync(folderName)
  async.forEachLimit(HOST_INFO_TYPES, 5, function(infoType, cb)
    debugInfo(infoType, function(debugData)
      fs.writeFile(path.join(folderName, infoType .. '.json'), debugData, cb)
    end)
  end, function()
    callback()
  end)
end

local function debugInfoAllTime(callback)
  local data = {}
  async.forEachLimit(HOST_INFO_TYPES, 5, function(infoType, cb)
    local start = uv.hrtime()
    debugInfo(infoType, function(_)
      local endTime = uv.hrtime() - start
      data[infoType] = endTime / 10000
      cb()
    end)
  end, function()
    callback(json.stringify(data, {indent = 2}))
  end)
end

local function debugInfoAllSize(callback)
  local folderName = 'tempDebug'
  local data = {}
  data.hostinfos = {}
  local totalSize = 0
  debugInfoAllToFolder(folderName, function()
    local files = fs.readdirSync(folderName)
    async.forEachLimit(files, 5, function(file, cb)
      local size = fs.statSync(path.join(folderName, file))['size']
      totalSize = totalSize + size
      data.hostinfos[file:sub(0, -6)] = size
      cb()
    end, function()
      fs.unlinkSync(folderName)
      data.total_size = totalSize
      callback(json.stringify(data, {indent = 2}))
    end)
  end)
end

--[[ Exports ]]--
local exports = {}
exports.create = create
exports.classes = classes
exports.getTypes = getTypes
exports.debugInfo = debugInfo
exports.debugInfoToFile = debugInfoToFile
exports.debugInfoAll = debugInfoAll
exports.debugInfoAllToFile = debugInfoAllToFile
exports.debugInfoAllToFolder = debugInfoAllToFolder
exports.debugInfoAllTime = debugInfoAllTime
exports.debugInfoAllSize = debugInfoAllSize
return exports
