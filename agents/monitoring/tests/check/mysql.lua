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

local helper = require('../helper')
local MySQLCheck = Check.MySQLCheck

local exports = {}

local function setupTest(tcName)
  env.set('VIRGO_SUBPROC_MOCK', 'monitoring/tests/check/mysql_mock', 1)
  env.set("VIRGO_SUBPROC_TESTCASE", tcName, 1)
end

exports['test_mysql_check_failed_init'] = function(test, asserts)
  setupTest('failed_init')
  local check = MySQLCheck:new({id='foo', period=30})
  asserts.is_nil(check._lastResult)
  check:run(function(result)
    asserts.not_nil(result, nil)
    asserts.not_nil(check._lastResult, nil)
    asserts.equal(result['_status'], "mysql_init failed")
    asserts.equal(result['_state'], "unavailable")
    test.done()
  end)
end

exports['test_mysql_check_failed_real_connect'] = function(test, asserts)
  setupTest('failed_real_connect')
  local check = MySQLCheck:new({id='foo', period=30, details={username='foobar'}})
  asserts.is_nil(check._lastResult)
  check:run(function(result)
    asserts.not_nil(result, nil)
    asserts.not_nil(check._lastResult, nil)
    asserts.equal(result['_status'], "mysql_real_connect(host=127.0.0.1, port=3306, username=foobar) failed: (42) mocked error")
    asserts.equal(result['_state'], "unavailable")
    test.done()
  end)
end

exports['test_mysql_check_mysql_query_failed'] = function(test, asserts)
  setupTest('failed_query')
  local check = MySQLCheck:new({id='foo', period=30})
  asserts.is_nil(check._lastResult)
  check:run(function(result)
    asserts.not_nil(result, nil)
    asserts.not_nil(check._lastResult, nil)
    asserts.equal(result['_status'], 'mysql_query "show status" failed: (42) mocked error')
    asserts.equal(result['_state'], "unavailable")
    test.done()
  end)
end

exports['test_mysql_check_use_result_failed'] = function(test, asserts)
  setupTest('failed_use_result')
  local check = MySQLCheck:new({id='foo', period=30})
  asserts.is_nil(check._lastResult)
  check:run(function(result)
    asserts.not_nil(result, nil)
    asserts.not_nil(check._lastResult, nil)
    asserts.equal(result['_status'], "mysql_use_result failed: (42) mocked error")
    asserts.equal(result['_state'], "unavailable")
    test.done()
  end)
end

exports['test_mysql_check_num_fields'] = function(test, asserts)
  setupTest('failed_num_fields')
  local check = MySQLCheck:new({id='foo', period=30})
  asserts.is_nil(check._lastResult)
  check:run(function(result)
    asserts.not_nil(result, nil)
    asserts.not_nil(check._lastResult, nil)
    asserts.equal(result['_status'], "mysql_num_fields failed: expected 2 fields, but got 3")
    asserts.equal(result['_state'], "unavailable")
    test.done()
  end)
end

exports['test_mysql_row_parsing'] = function(test, asserts)
  setupTest('fake_results')
  local check = MySQLCheck:new({id='foo', period=30, details={username='fooo'}})
  asserts.is_nil(check._lastResult)
  check:run(function(result)
    asserts.not_nil(result)
    asserts.not_nil(check._lastResult)
    local m = result:getMetrics()
    asserts.not_nil(m)
    asserts.not_nil(m['core'])
    asserts.not_nil(m['core']['uptime'])
    asserts.equal(m['core']['uptime']['t'], 'uint64')
    asserts.equal(m['core']['uptime']['u'], 'seconds')
    asserts.is_string(m['core']['uptime']['v'])
    asserts.is_number(tonumber(m['core']['uptime']['v']))
    asserts.equal(tonumber(m['core']['uptime']['v']), 3212)
    asserts.equal(tonumber(m['innodb']['buffer_pool_pages_flushed']['v']), 2)
    -- TOOD: more tests on values?
    -- asserts.equal(result['_status'], "mysql_num_fields failed: expected 2 fields, but got 3")
    asserts.ok(#check._lastResult:serialize() > 0)
    asserts.equal(result['_state'], "available")
    test.done()
  end)
end

if os.type() == "win32" then
  exports = helper.skip_all(exports, os.type())
end

return exports
