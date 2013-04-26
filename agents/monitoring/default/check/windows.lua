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
local os = require('os')

local function lines(str)
  local t = {}
  local function helper(line)
    table.insert(t, line)
    return ""
  end
  helper((str:gsub("(.-)\r?\n", helper)))
  return t
end

local WindowsPerfOSCheck = BaseCheck:extend()

function WindowsPerfOSCheck:initialize(params)
  BaseCheck.initialize(self, 'agent.windows_perfos', params)
end

--[[
# So this should create a Perf.csv file in the temp directory
powershell "(get-wmiobject Win32_PerfFormattedData_PerfOS_System).Properties | Select Name, Value, Type | ConvertTo-Csv"
--]]

local wmi_type_map = {
  uint8='uint32',
  uint16='uint32',
  uint32='uint32',
  uint64='uint64',
  sint8='int32',
  sint16='int32',
  sint32='int32',
  sint64='int64',
  real32='double',
  real64='double'
  }
local PerfOS_System_Properties_Ignore = {
  Caption=true,
  Description=true,
  Name=true,
  Frequency_Object=true,
  Frequency_PerfTime=true,
  Frequency_Sys100NS=true,
  Timestamp_Object=true,
  Timestamp_PerfTime=true,
  Timestamp_Sys100NS=true
  }

function WindowsPerfOSCheck:run(callback)
  -- Set up
  local callback = fireOnce(callback)
  local checkResult = CheckResult:new(self, {})
  local block_data = ''

  if os.type() ~= 'win32' then
    checkResult:setStatus("err agent.windows_perfos available only on Windows platforms")

    -- Return Result
    self._lastResult = checkResult
    callback(checkResult)
    return
  end

  -- Perform Check
  local options = {}
  local child = spawn('powershell.exe', {'(get-wmiobject Win32_PerfFormattedData_PerfOS_System).Properties | Select Name, Value, Type | ConvertTo-Csv'}, options)
  child.stdout:on('data', function(chunk)
    -- aggregate the output
    block_data = block_data .. chunk
  end)
  child:on('exit', function(exit_code)
    -- Build Dataset from Block Data
    local data_lines = lines(block_data)
    local count = 0
    local headings = {}
    for x, line in pairs(data_lines) do
      if string.sub(line,1,1) ~= '#' then
        count = count + 1
        if count == 1 then
          local temp = parseCSVLine(line)
          local i = 0
          -- Map headings to indexes
          for x, heading in pairs(temp) do
            i = i + 1
            headings[heading] = i
          end
        else
          -- Parse Data, coverting to numbers when needed
          local entry = parseCSVLine(line)
          if entry[headings['Name']] ~= nil and PerfOS_System_Properties_Ignore[entry[headings['Name']]] ~= true then
            local type = 'string'
            if entry[headings['Type']] ~= nil and wmi_type_map[string.lower(entry[headings['Type']])] ~=nil then
               entry[headings['Value']] = tonumber(entry[headings['Value']])
               type = wmi_type_map[string.lower(entry[headings['Type']])]
            end
            checkResult:addMetric(entry[headings['Name']], nil, type, entry[headings['Value']], '')
          end
        end
      end
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
