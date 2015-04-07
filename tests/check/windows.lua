local math = require('math')
local os = require('os')
local string = require('string')
local helper = require('../helper')
local fixtures = require('/tests/fixtures').checks
local WindowsChecks = require('/check/windows').checks

local exports = {}

exports['test_windowsperfos_check'] = function(test, asserts)
  local check = WindowsChecks.WindowsPerfOSCheck:new({id='foo', period=30})
  asserts.ok(check._lastResult == nil)
  check:run(function(result)
    asserts.ok(result ~= nil)
    asserts.ok(check._lastResult ~= nil)

    if os.type() == 'win32' then
      asserts.equals(result:getStatus(), 'success')
      asserts.ok(#check._lastResult:serialize() > 0)
      local metrics = result:getMetrics()['none']
      asserts.ok(metrics['Processes']['t'] == 'uint32')
      -- Values always become strings internally
      asserts.ok(tonumber(metrics['Processes']['v']) > 0)
   else
      asserts.ok(result:getStatus() ~= 'success')
    end
    test.done()
  end)
end

local function add_iterative_test(original_test_set, base_name, test_function)
  local test_name = 'test_' .. base_name
  if helper.test_configs == nil or helper.test_configs[test_name] == nil then
    original_test_set[test_name] = function(test, asserts)
      test.skip(test_name .. ' requires at least one config file entry')
    end
  else
    for i, config in ipairs(helper.test_configs[test_name]) do
      original_test_set[string.format('%s_%u', test_name, i)] = function(test, asserts)
        return test_function(test, asserts, config)
      end
    end
  end

  return original_test_set
end

local function add_iterative_and_fixture_test(original_test_set, base_name, test_function)
  local test_name = 'test_' .. base_name
  if not fixtures[base_name .. ".txt"] then
    original_test_set[test_name .. '_fixture'] = function(test, asserts)
      test.skip(test_name .. '_fixture, fixture is missing')
    end
  else
    original_test_set[test_name .. '_fixture'] = function(test, asserts)
      return test_function(test, asserts, {db='foo', powershell_csv_fixture=fixtures[base_name .. ".txt"]})
    end
  end

  return add_iterative_test(original_test_set, base_name, test_function)
end

local function mssql_test_common(check, test, asserts, specific_tests)
  asserts.ok(check._lastResult == nil)
  --p(check)
  check:run(function(result)
    asserts.ok(result ~= nil)
    asserts.ok(check._lastResult ~= nil)

    if os.type() == 'win32' or check:getPowershellCSVFixture() then
      asserts.equals(result:getStatus(), 'success')
      asserts.ok(#check._lastResult:serialize() > 0, "no metrics")
      --local metrics = result:getMetrics()['none']
      --p(metrics)
      specific_tests(result, test, asserts)
    else
      asserts.ok(result:getStatus() ~= 'success')
    end
    test.done()
  end)
end

exports = add_iterative_and_fixture_test(exports, 'mssql_database', function(test, asserts, config)
  mssql_test_common(WindowsChecks.MSSQLServerDatabaseCheck:new({id='foo', period=30, details=config}),
    test, asserts, function(result, test, asserts)
      local metrics = result:getMetrics()['none']
      -- Values always become strings internally
      asserts.ok(tonumber(metrics['size']['v']) > 0)
    end
  )
end)

exports = add_iterative_and_fixture_test(exports, 'mssql_buffer_manager', function(test, asserts, config)
  mssql_test_common(WindowsChecks.MSSQLServerBufferManagerCheck:new({id='foo', period=30, details=config}),
    test, asserts, function(result, test, asserts)
      local metrics = result:getMetrics()['none']
      -- Values always become strings internally
      asserts.ok(tonumber(metrics['total_pages']['v']) > 0)
    end
  )
end)

exports = add_iterative_and_fixture_test(exports, 'mssql_sql_statistics', function(test, asserts, config)
  mssql_test_common(WindowsChecks.MSSQLServerSQLStatisticsCheck:new({id='foo', period=30, details=config}),
    test, asserts, function(result, test, asserts)
      local metrics = result:getMetrics()['none']
      -- Values always become strings internally
      asserts.ok(tonumber(metrics['sql_attention_rate']['v']) >= 0)
    end
  )
end)

exports = add_iterative_and_fixture_test(exports, 'mssql_memory_manager', function(test, asserts, config)
  mssql_test_common(WindowsChecks.MSSQLServerMemoryManagerCheck:new({id='foo', period=30, details=config}),
    test, asserts, function(result, test, asserts)
      local metrics = result:getMetrics()['none']
      -- Values always become strings internally
      asserts.ok(tonumber(metrics['total_server_memory']['v']) > 0)
    end
  )
end)

exports = add_iterative_and_fixture_test(exports, 'mssql_plan_cache', function(test, asserts, config)
  mssql_test_common(WindowsChecks.MSSQLServerPlanCacheCheck:new({id='foo', period=30, details=config}),
    test, asserts, function(result, test, asserts)
      local metrics = result:getMetrics()['none']
      -- Values always become strings internally
      asserts.ok(tonumber(metrics['total_cache_pages']['v']) > 0)
    end
  )
end)


return exports
