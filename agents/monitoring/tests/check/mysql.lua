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

local JSON = require('json')
local path = require('path')
local os = require('os')

local Check = require('monitoring/default/check')
local Metric = require('monitoring/default/check/base').Metric
local constants = require('monitoring/default/util/constants')
local BaseCheck = Check.BaseCheck
local CheckResult = Check.CheckResult

local MySQLCheck = Check.MySQLCheck

local exports = {}

exports['test_mysql_check'] = function(test, asserts)
  local check = MySQLCheck:new({id='foo', period=30})
  asserts.ok(check._lastResult == nil)
  check:run(function(results)
    asserts.ok(results ~= nil)
    p(check._lastResult)
    asserts.ok(check._lastResult ~= nil)
    asserts.ok(#check._lastResult:serialize() > 0)
    asserts.ok(check._lastResult._nextRun)
    test.done()
  end)
end

return exports
