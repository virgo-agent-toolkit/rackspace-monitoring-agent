--[[
Copyright 2015 Rackspace

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

local los = require('los')
local env = require('env')
local uv = require('uv')
local Check = require('../check')
local MySQLCheck = Check.MySQLCheck

local function setupTest(tcName)
  env.set('VIRGO_SUBPROC_MOCK', uv.cwd() .. '/tests/mysql')
  env.set('VIRGO_SUBPROC_TESTCASE', tcName)
  env.set('LUVI_APP', '.')
  env.unset('LUVI_MAIN')
end

require('../tap')(function(test)
  test('test mysql check failed init', function(expect)
    if los.type() == 'win32' then p('skipping') ; return end
    setupTest('failed_init')
    local check = MySQLCheck:new({id='foo', period=30})
    assert(not check._lastResult)
    check:run(expect(function(result)
      assert(result)
      assert(check._lastResult)
      assert(result['_status'] == "mysql_init failed")
      assert(result['_state'] == "unavailable")
    end))
  end)

  test('test mysql check failed real connect', function(expect)
    if los.type() == 'win32' then p('skipping') ; return end
    setupTest('failed_real_connect')
    local check = MySQLCheck:new({id='foo', period=30, details={username='foobar'}})
    assert(not check._lastResult)
    check:run(expect(function(result)
      assert(result)
      assert(check._lastResult)
      assert(result['_status'] == "mysql_real_connect(host=127.0.0.1, port=3306, username=foobar) failed: (42) mocked error")
      assert(result['_state'] == "unavailable")
    end))
  end)

  test('test mysql check use result failed', function(expect)
    if los.type() == 'win32' then p('skipping') ; return end
    setupTest('failed_use_result')
    local check = MySQLCheck:new({id='foo', period=30})
    assert(not check._lastResult)
    check:run(expect(function(result)
      assert(result)
      assert(check._lastResult)
      assert(result['_status'] == "mysql_use_result failed: (42) mocked error")
      assert(result['_state'] == "unavailable")
    end))
  end)

  test('test mysql check row parsing', function(expect)
    if los.type() == 'win32' then p('skipping') ; return end
    setupTest('fake_results')
    local check = MySQLCheck:new({id='foo', period=30, details={username='fooo'}})
    assert(not check._lastResult)
    check:run(expect(function(result)
      assert(result)
      assert(check._lastResult)
      local m = result:getMetrics()
      assert(m)
      assert(m['core'])
      assert(m['core']['uptime'])
      assert(m['core']['uptime']['t'] == 'uint64')
      assert(m['core']['uptime']['u'] == 'seconds')
      assert(m['core']['uptime']['v'])
      assert(tonumber(m['core']['uptime']['v']))
      assert(tonumber(m['core']['uptime']['v']), 3212)
      assert(tonumber(m['innodb']['buffer_pool_pages_flushed']['v']), 2)
      assert(#check._lastResult:serialize() > 0)
      assert(result['_state'] == "available")
    end))
  end)

  test('test dbaas multi query', function(expect)
    if los.type() == 'win32' then p('skipping') ; return end
    setupTest('test_multi_query')
    local check = MySQLCheck:new({id='foo', period=30, details={username='fooo'}})
    check:run(expect(function(result)
      assert(check._lastResult)
      local m = result:getMetrics()
      -- show status result
      assert(tonumber(m['core']['uptime']['v']) == 2)
      -- show variables result
      assert(tonumber(m['qcache']['size']['v']) == 1)
      -- show slave status result
      assert(tonumber(m['replication']['slave_io_state']['v']) == 3)
    end))
  end)
end)
