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
local table = require('table')
local vutils = require('virgo_utils')

local sigarCtx = require('/sigar').ctx
local sigarutil = require('/base/util/sigar')

local HostInfo = require('./base').HostInfo
local CPUInfo = require('./cpu').CPUInfo
local DiskInfo = require('./disk').DiskInfo
local FilesystemInfo = require('./filesystem').FilesystemInfo
local MemoryInfo = require('./memory').MemoryInfo
local NetworkInfo = require('./network').NetworkInfo
local NilInfo = require('./nil').NilInfo
local ProcessInfo = require('./procs').ProcessInfo
local SystemInfo = require('./system').SystemInfo
local WhoInfo = require('./who').WhoInfo

local asserts = require('bourbon').asserts

local hostInfo_classes = {
  CPUInfo = CPUInfo,
  MemoryInfo = MemoryInfo,
  NetworkInfo = NetworkInfo,
  DiskInfo = DiskInfo,
  ProcessInfo = ProcessInfo,
  FilesystemInfo = FilesystemInfo,
  SystemInfo = SystemInfo,
  WhoInfo = WhoInfo
}

local function create_map()
  local map = {}
  for x, hostInfo_class in pairs(hostInfo_classes) do
    asserts.ok(hostInfo_class.getType and hostInfo_class.getType(), "HostInfo getType() undefined or returning nil: " .. tostring(x))
    map[hostInfo_class.getType()] = hostInfo_class
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
return exports
