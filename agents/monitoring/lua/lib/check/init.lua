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

local CpuCheck = require('./cpu').CpuCheck
local DiskCheck = require('./disk').DiskCheck
local MemoryCheck = require('./memory').MemoryCheck
local NetworkCheck = require('./network').NetworkCheck

local fmt = require('string').format

function create(checkData)
  local _type = checkData.type
  local obj = {
    id = checkData.id,
    period = checkData.period,
    state = 'OK'
  }
  if _type == 'agent.memory' then
    return MemoryCheck:new(obj)
  elseif _type == 'agent.disk' then
    return DiskCheck:new(obj)
  elseif _type == 'agent.memory' then
    return MemoryCheck:new(obj)
  elseif _type == 'agent.network' then
    return NetworkCheck:new(obj)
  elseif _type == 'agent.cpu' then
    return CpuCheck:new(obj)
  end
  return nil
end

local exports = {}
exports.BaseCheck = BaseCheck
exports.CheckResult = CheckResult

exports.CpuCheck = CpuCheck
exports.DiskCheck = DiskCheck
exports.MemoryCheck = MemoryCheck
exports.NetworkCheck = NetworkCheck

exports.create = create
return exports
