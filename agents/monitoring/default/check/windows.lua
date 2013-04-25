--[[
Copyright 2013 Rackspace

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
local spawn = require('childprocess').spawn
local fireOnce = require('../util/misc').fireOnce
local parseCSVLine = require('../util/misc').parseCSVLine
local table = require('table')
local string = require('string')

local function lines(str)
  local t = {}
  local function helper(line) table.insert(t, line) return "" end
  helper((str:gsub("(.-)\r?\n", helper)))
  return t
end

local WindowsPerfOSCheck = BaseCheck:extend()

function WindowsPerfOSCheck:initialize(params)
  BaseCheck.initialize(self, 'agent.windows_perfos', params)
end

--[[
# So this should create a Perf.csv file in the temp directory
powershell "\$env:PERF = \$env:TEMP + \"\\Perf.csv\" ; get-wmiobject Win32_PerfFormattedData_PerfOS_System | Export-Csv \$env:PERF ; type \$env:PERF"
--]]

function WindowsPerfOSCheck:run(callback)
  -- Set up
  local callback = fireOnce(callback)
  local checkResult = CheckResult:new(self, {})
  local block_data = ''

  -- Perform Check
  local options = {}
  local child = spawn('powershell.exe', {'$env:PERF = $env:TEMP + "\\Perf.csv" ; get-wmiobject Win32_PerfFormattedData_PerfOS_System | Export-Csv $env:PERF ; type $env:PERF'}, options)
  child.stdout:on('data', function(chunk)
    -- aggregate the output
    block_data = block_data .. chunk
  end)
  child:on('exit', function(exit_code)
    -- Build Dataset from Block Data
    local headings = {}
    local values = {}
    local data_lines = lines(block_data)
    local count = 0
    for x, line in pairs(data_lines) do
      if string.sub(line,1,1) ~= '#' then
        count = count + 1
        if count == 1 then
          headings = parseCSVLine(line)
        end
        if count == 2 then
          values = parseCSVLine(line)
        end
      end
    end

    -- Input metrics into Result
    for i = 1, table.getn(headings) do
      local v = tonumber(values[i])
      if v == nil and values[i] ~= nil then
        v = values[i]
      end
      checkResult:addMetric(headings[i], nil, 'gauge', values[i], '')
    end

    -- Return Result
    self._lastResult = checkResult
    callback(checkResult)
  end)
  child:on('error', function(err)
    checkResult:setStatus("err " .. err)

    -- Return Result
    self._lastResult = checkResult
    callback(checkResult)
  end)
end

local exports = {}
exports.WindowsPerfOSCheck = WindowsPerfOSCheck
return exports
