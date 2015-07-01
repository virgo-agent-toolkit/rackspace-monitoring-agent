local los = require('los')
local WindowsChecks = require('../check/windows').checks
local env = require('env')
local fixtures = require('./fixtures').checks


require('tap')(function(test)
  test('check WindowsPerfOSCheck', function(expect)
    local check = WindowsChecks.WindowsPerfOSCheck:new({id='foo', period=30})
    assert(check._lastResult == nil)
    check:run(expect(function(result)
      assert(result ~= nil)
      assert(check._lastResult ~= nil)

      if los.type() == 'win32' then
        assert(result:getStatus() == 'success')
        assert(#check._lastResult:serialize() > 0)
        local metrics = result:getMetrics()['none']
        assert(metrics['Processes']['t'] == 'uint32')
        -- Values always become strings internally
        assert(tonumber(metrics['Processes']['v']) > 0)
      else
        assert(result:getStatus() ~= 'success')
      end
    end))
  end)

  local on_appveyor = env.get('APPVEYOR') == 'True'
  local service_configs
  if on_appveyor then
    service_configs = {
      sql2008 = {
        serverinstance = '\\MSSQL$SQL2008R2SP2',
        username = 'sa',
        password = 'Password12!'
      }
    }
  end

  local function mssql_test_common(check, expect, specific_tests)
    assert(check._lastResult == nil)
    --p(check)
    check:run(expect(function(result)
      p(check)
      assert(result ~= nil)
      assert(check._lastResult ~= nil)

      if los.type() == 'win32' or check:getPowershellCSVFixture() then
        assert(result:getStatus() == 'success')
        assert(#check._lastResult:serialize() > 0, "no metrics")
        local metrics = result:getMetrics()['none']
        p(metrics)
        specific_tests(result, expect)
      else
        assert(result:getStatus() ~= 'success')
      end
    end))
  end

  local function test_with_fixture(base_name, test, db_required, test_function)
    test('check ' .. base_name, function(expect)
      if service_configs then
        for service, config in pairs(service_configs) do
          p('check ' .. base_name .. ' ' .. service)
          if (not db_required) or (db_required and config.db ~= nil) then
            test_function(expect, config)
          else
            p('db not found, skipping check ' .. base_name .. ' ' .. service)
          end
        end
      else
        if not fixtures[base_name .. ".txt"] then
          p('fixture not found, skipping ' .. base_name)
        else
          p('check ' .. base_name .. ' using fixture')
          test_function(expect, {db='foo', powershell_csv_fixture=fixtures[base_name .. ".txt"]})
        end
      end
    end)
  end

  test_with_fixture('mssql_database', test, true, function(expect, config)
    mssql_test_common(WindowsChecks.MSSQLServerDatabaseCheck:new({id='foo', period=30, details=config}),
      expect, function(result, expect)
        local metrics = result:getMetrics()['none']
        -- Values always become strings internally
        assert(tonumber(metrics['size']['v']) > 0)
      end
    )
  end)

  test_with_fixture('mssql_buffer_manager', test, false, function(expect, config)
    mssql_test_common(WindowsChecks.MSSQLServerBufferManagerCheck:new({id='foo', period=30, details=config}),
      expect, function(result, expect)
        local metrics = result:getMetrics()['none']
        -- Values always become strings internally
        assert(tonumber(metrics['database_pages']['v']) > 0)
      end
    )
  end)

  test_with_fixture('mssql_sql_statistics', test, false, function(expect, config)
    mssql_test_common(WindowsChecks.MSSQLServerSQLStatisticsCheck:new({id='foo', period=30, details=config}),
      expect, function(result, expect)
        local metrics = result:getMetrics()['none']
        -- Values always become strings internally
        assert(tonumber(metrics['sql_attention_rate']['v']) >= 0)
      end
    )
  end)

  test_with_fixture('mssql_memory_manager', test, false, function(expect, config)
    mssql_test_common(WindowsChecks.MSSQLServerMemoryManagerCheck:new({id='foo', period=30, details=config}),
      expect, function(result, expect)
        local metrics = result:getMetrics()['none']
        -- Values always become strings internally
        assert(tonumber(metrics['total_server_memory']['v']) > 0)
      end
    )
  end)

  test_with_fixture('mssql_plan_cache', test, false, function(expect, config)
    mssql_test_common(WindowsChecks.MSSQLServerPlanCacheCheck:new({id='foo', period=30, details=config}),
      expect, function(result, expect)
        local metrics = result:getMetrics()['none']
        -- Values always become strings internally
        assert(tonumber(metrics['total_cache_pages']['v']) > 0)
      end
    )
  end)

  end)

