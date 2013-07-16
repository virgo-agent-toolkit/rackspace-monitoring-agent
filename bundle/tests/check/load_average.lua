local os = require('os')
local myCheck = require('/check').LoadAverageCheck
local exports = {}
exports['test_load_average_check'] = function(test, asserts)
--  test.done()
  local check = myCheck:new({id='foo',period=30})
  asserts.ok(check._lastResult == nil)
  check:run(function(result)
   if os.type() == "win32" then
      -- Check isn't portable to win32, but make sure it still reports unavailable correctly.
      asserts.ok(result ~= nil)
      asserts.ok(check._lastResult == nil)
      asserts.equal(result['_state'], "unavailable")
      asserts.equal(result['_status'], "Load Average checks are not supported on Windows.")
      test.done()
    else
      asserts.ok(result ~= nil)
      asserts.equal(result['_state'], "available")
      local m = result:getMetrics()['none']
      asserts.not_nil(m)
      asserts.not_nil(m['1m'])
      asserts.not_nil(m['5m'])
      asserts.not_nil(m['15m'])
      asserts.is_number(tonumber(m['5m']['v']))
      asserts.equal(m['5m']['t'], 'double')
      asserts.ok(check._lastResult ~= nil)
      asserts.ok(#check._lastResult:serialize() > 0)
      test.done()
    end
  end)
end
return exports
