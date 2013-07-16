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

local WindowsPowershellCmdletCheck = require('./winbase').WindowsPowershellCmdletCheck
local string = require('string')

local WindowsPerfOSCheck = WindowsPowershellCmdletCheck:extend()

function WindowsPerfOSCheck:initialize(params)
  local cmd = "(get-wmiobject -ErrorVariable virgo_err Win32_PerfFormattedData_PerfOS_System).Properties | Select Name, Value, Type | ConvertTo-Csv"

  WindowsPowershellCmdletCheck.initialize(self, cmd, params)
end

function WindowsPerfOSCheck:getType()
  return 'agent.windows_perfos'
end

function WindowsPerfOSCheck:handle_entry(entry)
  local metric = nil
  if entry.Name then
    local blacklist = {
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
    local type_map = {
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

    if not blacklist[entry.Name] then
      local type = 'string'
      if type_map[string.lower(entry.Type)] then
        type = type_map[string.lower(entry.Type)]
      end

      metric = {
        Name = entry.Name,
        Dimension = nil,
        Type = type,
        Value = entry.Value,
        unit = ''
      }
    end
  end
  return metric
end


local exports = {}
exports.WindowsPerfOSCheck = WindowsPerfOSCheck
return exports
