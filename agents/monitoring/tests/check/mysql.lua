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
local env = require('env')

local Check = require('monitoring/default/check')
local Metric = require('monitoring/default/check/base').Metric
local constants = require('monitoring/default/util/constants')
local BaseCheck = Check.BaseCheck
local CheckResult = Check.CheckResult

local MySQLCheck = Check.MySQLCheck

local exports = {}

local function setupTest(tcName)
  env.set('VIRGO_SUBPROC_MOCK', 'monitoring/tests/check/mysql_mock', 1)
  env.set("VIRGO_SUBPROC_TESTCASE", tcName, 1)
end

exports['test_mysql_check_failed_init'] = function(test, asserts)
  setupTest('failed_init')
  local check = MySQLCheck:new({id='foo', period=30})
  asserts.ok(check._lastResult == nil)
  check:run(function(results)
    asserts.not_nil(results, nil)
    asserts.not_nil(check._lastResult, nil)
    asserts.equal(results['_status'], "mysql_init failed")
    asserts.equal(results['_state'], "unavailable")
    test.done()
  end)
end

exports['test_mysql_check_failed_real_connect'] = function(test, asserts)
  setupTest('failed_real_connect')
  local check = MySQLCheck:new({id='foo', period=30})
  asserts.ok(check._lastResult == nil)
  check:run(function(results)
    asserts.not_nil(results, nil)
    asserts.not_nil(check._lastResult, nil)
    asserts.equal(results['_status'], "mysql_real_connect failed: (42) mocked error")
    asserts.equal(results['_state'], "unavailable")
    test.done()
  end)
end

exports['test_mysql_check_mysql_query_failed'] = function(test, asserts)
  setupTest('failed_query')
  local check = MySQLCheck:new({id='foo', period=30})
  asserts.ok(check._lastResult == nil)
  check:run(function(results)
    asserts.not_nil(results, nil)
    asserts.not_nil(check._lastResult, nil)
    asserts.equal(results['_status'], "mysql_query \"show status\" failed: (42) mocked error")
    asserts.equal(results['_state'], "unavailable")
    test.done()
  end)
end

return exports
