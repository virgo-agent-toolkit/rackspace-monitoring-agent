--[[
Copyright 2014 Rackspace

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

local env = require('env')
local os = require('os')

local Check = require('/check')
local Metric = require('/check/base').Metric

local helper = require('../helper')

local BaseCheck = Check.BaseCheck
local CheckResult = Check.CheckResult
local DBaaSMySQLCheck = Check.DBaaSMySQLCheck

local function setupTest(tcName)
  env.set('VIRGO_SUBPROC_MOCK', '/tests/check/mysql_mock', 1)
  env.set("VIRGO_SUBPROC_TESTCASE", tcName, 1)
end

local exports = {}

exports['test_dbaas_multi_query'] = function(test, asserts)
  local check

  setupTest('test_multi_query')

  check = DBaaSMySQLCheck:new({id='foo', period=30, details={username='fooo'}})
  check:run(function(result)
    asserts.not_nil(check._lastResult)
    local m = result:getMetrics()
    -- show status result
    asserts.equal(tonumber(m['core']['uptime']['v']), 2)
    -- show variables result
    asserts.equal(tonumber(m['qcache']['size']['v']), 1)
    -- show slave status result
    asserts.equal(tonumber(m['replication']['slave_io_state']['v']), 3)
    test.done()
  end)
end

if os.type() == "win32" then
  exports = helper.skip_all(exports, os.type())
end

return exports
