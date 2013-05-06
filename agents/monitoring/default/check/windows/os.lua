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

local WindowsPerfOSCheck = WindowsPowershellCmdletCheck:extend()

function WindowsPerfOSCheck:initialize(params)
  local cmd = "(get-wmiobject Win32_PerfFormattedData_PerfOS_System).Properties | Select Name, Value, Type | ConvertTo-Csv"

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

  WindowsPowershellCmdletCheck.initialize(self, 'agent.windows_perfos', cmd, PerfOS_System_Properties_Ignore, wmi_type_map, params)
end


local exports = {}
exports.WindowsPerfOSCheck = WindowsPerfOSCheck
return exports
