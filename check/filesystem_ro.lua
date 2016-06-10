--[[
Copyright 2016 Rackspace

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
local gatherReadWriteReadOnlyInfo = require('../ro').gatherReadWriteReadOnlyInfo
local BaseCheck = require('./base').BaseCheck
local CheckResult = require('./base').CheckResult
local table = require('table')
local los = require('los')

local FileSystemCheckRO = BaseCheck:extend()

local UNITS = {
  total = 'total',
  devices = 'devices'
}

function FileSystemCheckRO:initialize(params)
  BaseCheck.initialize(self, params)
end

function FileSystemCheckRO:getType()
  return 'agent.filesystem_ro'
end

function FileSystemCheckRO:run(callback)
  local checkResult = CheckResult:new(self, {})
  if los.type() ~= 'linux' then
    checkResult:setStatus("err " .. self:getType() .. " available only on Linux platforms")
    self._lastResult = checkResult
    return callback(checkResult)
  end
  local fs_list_ro, fs_list_rw = gatherReadWriteReadOnlyInfo()
  checkResult:addMetric('total_ro', nil, nil, #fs_list_ro, UNITS['total'])
  checkResult:addMetric('total_rw', nil, nil, #fs_list_rw, UNITS['total'])
  checkResult:addMetric('devices_ro', nil, nil, table.concat(fs_list_ro, ','), UNITS['devices'])
  checkResult:addMetric('devices_rw', nil, nil, table.concat(fs_list_rw, ','), UNITS['devices'])
  callback(checkResult)
end

exports.FileSystemCheckRO = FileSystemCheckRO
