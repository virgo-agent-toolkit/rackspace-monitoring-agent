local los = require('los')
local LoadAverageCheck = require('../check').LoadAverageCheck
require('../tap')(function(test)
  test('test check load average', function(expect)
    local check = LoadAverageCheck:new({id='foo',period=30})
    assert(not check._lastResult)
    check:run(function(result)
      if los.type() == "win32" then
        -- Check isn't portable to win32, but make sure it still reports unavailable correctly.
        assert(result ~= nil)
        assert(check._lastResult == nil)
        assert(result['_state'] == "unavailable")
        assert(result['_status'] == "Load Average checks are not supported on Windows.")
      else
        assert(result ~= nil)
        assert(result['_state'], "available")
        local m = result:getMetrics()['none']
        assert(m)
        assert(m['1m'])
        assert(m['5m'])
        assert(m['15m'])
        assert(tonumber(m['5m']['v']))
        assert(m['5m']['t'] == 'double')
        assert(check._lastResult ~= nil)
        assert(#check._lastResult:serialize() > 0)
      end
    end)
  end)
end)
