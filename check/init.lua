--[[
Copyright 2012 Rackspace

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

local BaseCheck = require('./base').BaseCheck
local CheckResult = require('./base').CheckResult

local ApacheCheck = require('./apache').ApacheCheck
local CpuCheck = require('./cpu').CpuCheck
local DiskCheck = require('./disk').DiskCheck
local FileSystemCheck = require('./filesystem').FileSystemCheck
local HostInfoCheck = require('./hostinfo').HostInfoCheck
local MemoryCheck = require('./memory').MemoryCheck
local NetworkCheck = require('./network').NetworkCheck
local MySQLCheck = require('./mysql').MySQLCheck
local RedisCheck = require('./redis').RedisCheck
local RaxxenCheck = require('./raxxen').RaxxenCheck
local NullCheck = require('./null').NullCheck
local LoadAverageCheck = require('./load_average').LoadAverageCheck
local PluginCheck = require('./plugin').PluginCheck
local Windows = require('./windows')

local timer = require('timer')
local math = require('math')

local Error = require('core').Error

local merge = require('virgo/util/misc').merge

local check_classes = {
  ApacheCheck = ApacheCheck,
  CpuCheck = CpuCheck,
  DiskCheck = DiskCheck,
  FileSystemCheck = FileSystemCheck,
  HostInfoCheck = HostInfoCheck,
  LoadAverageCheck = LoadAverageCheck,
  MemoryCheck = MemoryCheck,
  MySQLCheck = MySQLCheck,
  NetworkCheck = NetworkCheck,
  PluginCheck = PluginCheck,
  RaxxenCheck = RaxxenCheck,
  RedisCheck = RedisCheck,
  NullCheck = NullCheck
}
check_classes = merge(check_classes, Windows.checks)

local function create_map()
  local map = {}
  for x, check_class in pairs(check_classes) do
    map[check_class.getType()] = check_class
  end
  return map
end

local check_type_map = create_map()

local function create(checkData)
  local check = nil
  local checkType = checkData.type
  local obj = {
    id = checkData.id,
    period = checkData.period,
    details = checkData.details
  }

  if check_type_map[checkType] then
    check = check_type_map[checkType]:new(obj)
  end

  return check
end

-- Test Check
local function test(checkParams, callback)
  if type(checkParams) ~= 'table' then
    callback(Error:new('checkParams is not a table'))
    return
  end
  local check = create(checkParams)
  if not check then
    return callback(Error:new('Invalid check type'))
  end
  local timeout = math.random(25, 25) -- milliseconds
  timer.setTimeout(timeout, function()
    check:run(function(results)
      callback(nil, check, results)
    end)
  end)
end

-- Fetch Targets
local function targets(checkType, callback)
  if type(checkType) ~= 'string' then
    callback(Error:new('checkParams is not a string'))
    return
  end
  local checkParams = {
    id = 'targetRequest',
    period = 0,
    details = {},
    type = checkType
  }
  local check = create(checkParams)
  if check then
    check:getTargets(callback)
  else
    callback(Error:new('Invalid check type'))
  end
end

exports.BaseCheck = BaseCheck
exports.CheckResult = CheckResult

exports = merge(exports, check_classes)

exports.create = create
exports.test = test
exports.targets = targets
