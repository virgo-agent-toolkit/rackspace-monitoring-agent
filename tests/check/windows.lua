local math = require('math')
local os = require('os')

local WindowsPerfOSCheck = require('/check/windows').WindowsPerfOSCheck

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

return exports