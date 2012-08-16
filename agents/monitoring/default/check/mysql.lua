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

local SubProcCheck = require('./base').SubProcCheck

local MySQLCheck = SubProcCheck:extend()
local CheckResult = require('./base').CheckResult

function MySQLCheck:initialize(params)
  SubProcCheck.initialize(self, 'agent.mysql', params)
end

function MySQLCheck:_runCheckInChild(callback)
  local cr = CheckResult:new(self, {})

  local mysqlexact = {
    'libmysqlclient_r',
    'libmysqlclient',
  }

  local mysqlpattern = {
    'libmysqlclient_r%.so.*',
    'libmysqlclient_r%.dylib.*',
    'libmysqlclient_r%.dll.*',
    'libmysqlclient%.so.*',
    'libmysqlclient%.dylib.*',
    'libmysqlclient%.dll.*',
  }

  local mysqlpaths = {
    '/usr/lib',
    '/usr/local/lib',
    '/usr/local/mysql/lib',
    '/opt/local/lib',
  }

  local err, clib = self:_findLibrary(mysqlexact, mysqlpattern, mysqlpaths)
  if clib == nil then
    cr:setError('Couldn\'t find libmysqlclient_r')
    callback(cr)
    return
  end

  cr:setError('Found mysqlclient, but not implemented')
  callback(cr)
end

local exports = {}
exports.MySQLCheck = MySQLCheck
return exports
