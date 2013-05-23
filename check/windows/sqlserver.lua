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
local CheckResult = require('../base').CheckResult

-- A wrapper around an SQL Server Query

local MSSQLServerInvokeSQLCmdCheck = WindowsPowershellCmdletCheck:extend()

function MSSQLServerInvokeSQLCmdCheck:_invokesql_notfound(callback)
  local cr = CheckResult:new(self, {})
  cr:setError("Invoke-SqlCmd not found")
  self._lastResult = cr
  callback(cr)
  return
end

function MSSQLServerInvokeSQLCmdCheck:initialize(checkType, query, metric_blacklist, metric_type_map, params)
  if params.details == nil then
    params.details = {}
  end

  local serverinstance_option = ""
  local hostname_option = ""
  local username_option = ""
  local password_option = ""

  if params.details.hostname ~= nil and params.details.hostname ~= "" then
    hostname_option = "-Hostname \"" .. params.details.hostname .. "\" "
  end
  if params.details.serverinstance ~= nil and params.details.serverinstance ~= "" then
    serverinstance_option = "-ServerInstance \"" .. params.details.serverinstance .. "\" "
  end
  if params.details.username ~= nil and params.details.username ~= "" then
    username_option = "-Username \"" .. params.details.username .. "\" "
  end
  if params.details.password ~= nil and params.details.password ~= "" then
    password_option = "-Password \"" .. params.details.password .. "\" "
  end

  local cmd = "add-pssnapin -errorAction SilentlyContinue sqlservercmdletsnapin100 ; if (Get-Command Invoke-Sqlcmd -errorAction SilentlyContinue) { Invoke-Sqlcmd " .. hostname_option .. serverinstance_option .. username_option .. password_option .. " -Query \"" .. query .. "\" -QueryTimeout 10 | ConvertTo-Csv }"
  
  WindowsPowershellCmdletCheck.initialize(self, checkType, cmd, metric_blacklist, metric_type_map, params)
end

-- Get the Server Version Info

local MSSQLServerVersionCheck = MSSQLServerInvokeSQLCmdCheck:extend()

function MSSQLServerVersionCheck:initialize(params)
  local query = "select 'ProductVersion' as Name, SERVERPROPERTY('productversion') as Value, 'string' as Type; select 'ProductLevel' as Name, SERVERPROPERTY('productlevel') as Value, 'string' as Type; select 'Edition' as Name, SERVERPROPERTY('edition') as Value, 'string' as Type;"

  MSSQLServerInvokeSQLCmdCheck.initialize(self, 'agent.mssql_version', query, {}, {}, params)
end

-- Get Some Individual DB State

local MSSQLServerDatabaseCheck = MSSQLServerInvokeSQLCmdCheck:extend()

function MSSQLServerDatabaseCheck:_db_unspec(callback)
  local cr = CheckResult:new(self, {})
  cr:setError("Database unspecified")
  self._lastResult = cr
  callback(cr)
  return
end

function MSSQLServerDatabaseCheck:initialize(params)
  local query = ""
  if params.details == nil then
    params.details = {}
  end

  local query = ""
  if params.details.db == nil then
    -- Set the check to error if no db was specified
    self.run = self._db_unspec
  else
    local q1 = "select unpvt.N as Name, unpvt.Value, 'string' as Type from (select * from sys.databases where name = '" .. params.details.db .. "') p UNPIVOT (Value for N in (state_desc, recovery_model_desc, page_verify_option_desc) ) unpvt;"
    local q2 = "select unpvt.N as Name, unpvt.Value, 'int' as Type from (select * from sys.databases where name = '" .. params.details.db .. "') p UNPIVOT (Value for N in (state, recovery_model, page_verify_option) ) unpvt;"
    local q3 = "select unpvt.N as Name, unpvt.Value, 'int' as Type from (select * from sys.master_files where name = '" .. params.details.db .. "' and file_id = 1) p UNPIVOT (Value for N in (size, growth) ) unpvt;"
    query = q1 .. q2 .. q3
  end

  MSSQLServerInvokeSQLCmdCheck.initialize(self, 'agent.mssql_database', query, {}, {int="int64"}, params)
end

local exports = {}
exports.MSSQLServerVersionCheck = MSSQLServerVersionCheck
exports.MSSQLServerDatabaseCheck = MSSQLServerDatabaseCheck
return exports
