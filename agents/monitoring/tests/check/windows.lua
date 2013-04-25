local math = require('math')
local os = require('os')

local WindowsPerfOS = require('monitoring/default/check/windows').WindowsPerfOS

local exports = {}

exports['test_windowsperfos_check'] = function(test, asserts)
  local check = WindowsPerfOS:new({id='foo', period=30})
  asserts.ok(check._lastResult == nil)
  check:run(function(result)
    asserts.ok(result ~= nil)
    asserts.ok(check._lastResult ~= nil)
    asserts.ok(#check._lastResult:serialize() > 0)

    local metrics = result:getMetrics()['none']
    asserts.ok(metrics['__CLASS']['v'] == 'Win32_PerfFormattedData_PerfOS_System')

    test.done()
  end)
end

return exports
