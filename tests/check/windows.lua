local math = require('math')
local os = require('os')
local string = require('string')
local helper = require('../helper')

local WindowsPerfOSCheck = require('/check/windows').checks.WindowsPerfOSCheck
local MSSQLServerVersionCheck = require('/check/windows').checks.MSSQLServerVersionCheck
local MSSQLServerDatabaseCheck = require('/check/windows').checks.MSSQLServerDatabaseCheck

local exports = {}

exports['test_windowsperfos_check'] = function(test, asserts)
  local check = WindowsPerfOSCheck:new({id='foo', period=30})
  asserts.ok(check._lastResult == nil)
  check:run(function(result)
    asserts.ok(result ~= nil)
    asserts.ok(check._lastResult ~= nil)

    if os.type() == 'win32' then
      asserts.ok(result:getStatus() == 'success')
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

if helper.test_configs['test_sqlserver_check'] == nil then
  exports['test_sqlserver_check'] = function(test, asserts)
    test.skip('test_sqlserver_check requires at least one config file entry')
  end
else
  for i, config in ipairs(helper.test_configs['test_sqlserver_check']) do
    local name = string.format('test_sqlserver_check_%u', i)
    exports[name] = function(test, asserts)
      local check = MSSQLServerDatabaseCheck:new({id='foo', period=30, details=config})
      asserts.ok(check._lastResult == nil)
      check:run(function(result)
        asserts.ok(result ~= nil)
        asserts.ok(check._lastResult ~= nil)

        if os.type() == 'win32' then
          asserts.ok(result:getStatus() == 'success')
          asserts.ok(#check._lastResult:serialize() > 0)
          local metrics = result:getMetrics()['none']
          -- Values always become strings internally
          asserts.ok(tonumber(metrics['size']['v']) > 0)
        else
          asserts.ok(result:getStatus() ~= 'success')
        end
        test.done()
      end)
    end
  end
end

return exports
