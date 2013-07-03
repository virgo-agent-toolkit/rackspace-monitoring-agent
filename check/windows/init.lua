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

local WindowsPerfOSCheck = require('./os').WindowsPerfOSCheck
local MSSQLServer = require('./sqlserver')

local exports = {}

exports.create = function(self, checkType, obj)
  if checkType == 'agent.windows_perfos' then
    return WindowsPerfOSCheck:new(obj)
  elseif checkType == 'agent.mssql_version' then
    return MSSQLServer.MSSQLServerVersionCheck:new(obj)
  elseif checkType == 'agent.mssql_database' then
    return MSSQLServer.MSSQLServerDatabaseCheck:new(obj)
  elseif checkType == 'agent.mssql_buffer_manager' then
    return MSSQLServer.MSSQLServerBufferManagerCheck:new(obj)
  elseif checkType == 'agent.mssql_sql_statistics' then
    return MSSQLServer.MSSQLServerSQLStatisticsCheck:new(obj)
  elseif checkType == 'agent.mssql_memory_manager' then
    return MSSQLServer.MSSQLServerMemoryManagerCheck:new(obj)
  elseif checkType == 'agent.mssql_plan_cache' then
    return MSSQLServer.MSSQLServerPlanCacheCheck:new(obj)
  else
    return nil
  end
end

exports.checks = {
  WindowsPerfOSCheck = WindowsPerfOSCheck,
  MSSQLServerVersionCheck = MSSQLServer.MSSQLServerVersionCheck,
  MSSQLServerDatabaseCheck = MSSQLServer.MSSQLServerDatabaseCheck,
  MSSQLServerBufferManagerCheck = MSSQLServer.MSSQLServerBufferManagerCheck,
  MSSQLServerSQLStatisticsCheck = MSSQLServer.MSSQLServerSQLStatisticsCheck,
  MSSQLServerMemoryManagerCheck = MSSQLServer.MSSQLServerMemoryManagerCheck,
  MSSQLServerPlanCacheCheck = MSSQLServer.MSSQLServerPlanCacheCheck
  }

return exports
