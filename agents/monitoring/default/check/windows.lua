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

local function WindowsPerfOSCheck:initialize(params)
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

local function invokesql_notfound(callback)
  local cr = CheckResult:new(self, {})
  cr:setError("Invoke-SqlCmd not found")
  self._lastResult = cr
  callback(cr)
  return
end

local function db_unspec(callback)
  local cr = CheckResult:new(self, {})
  cr:setError("Database unspecified")
  self._lastResult = cr
  callback(cr)
  return
end

-- A wrapper around an SQL Server Query

local MSSQLServerInvokeSQLCmdCheck = WindowsPowershellCmdletCheck:extend()

local function MSSQLServerInvokeSQLCmdCheck:initialize(checkType, query, metric_blacklist, metric_type_map, params)
  local cmd = "if (Get-Command Invoke-Sqlcmd -errorAction SilentlyContinue) { Invoke-Sqlcmd -Query \"" .. query .. "\" -QueryTimeout 3 | ConvertTo-Csv }"

  WindowsPowershellCmdletCheck.initialize(self, checkType, cmd, metric_blacklist, metric_type_map, params)
end

-- Get the Server Version Info

local MSSQLServerVersionCheck = MSSQLServerInvokeSQLCmdCheck:extend()

local function MSSQLServerVersionCheck:initialize(params)
  local query = "select 'ProductVersion' as Name, SERVERPROPERTY('productversion') as Value, 'string' as Type; select 'ProductLevel' as Name, SERVERPROPERTY('productlevel') as Value, 'string' as Type; select 'Edition' as Name, SERVERPROPERTY('edition') as Value, 'string' as Type;"

  MSSQLServerInvokeSQLCmdCheck.initialize(self, 'agent.mssql_version', query, {}, {}, params)
end

-- Get Some Individual DB State

local MSSQLServerDatabaseCheck = MSSQLServerInvokeSQLCmdCheck:extend()

local function MSSQLServerDatabaseCheck:initialize(params)
  local query = ""
  if params.details == nil then
    params.details = {}
  end

  local query = ""
  if params.details.db == nil then
    -- Set the check to error if no db was specified
    self.run = db_unspec
  else
    local q1 = "select unpvt.N as Name, unpvt.Value, 'string' as Type from (select * from sys.databases where name = '" .. params.details.db .. "') p UNPIVOT (Value for N in (state_desc, recovery_model_desc, page_verify_option_desc) ) unpvt;"
    local q2 = "select unpvt.N as Name, unpvt.Value, 'int' as Type from (select * from sys.databases where name = '" .. params.details.db .. "') p UNPIVOT (Value for N in (state, recovery_model, page_verify_option) ) unpvt;"
    query = q1 .. q2
  end

  MSSQLServerInvokeSQLCmdCheck.initialize(self, 'agent.mssql_version', query, {}, {int="int64"}, params)
end

local exports = {}
exports.WindowsPerfOSCheck = WindowsPerfOSCheck
exports.MSSQLServerVersionCheck = MSSQLServerVersionCheck
exports.MSSQLServerDatabaseCheck = MSSQLServerDatabaseCheck
return exports
