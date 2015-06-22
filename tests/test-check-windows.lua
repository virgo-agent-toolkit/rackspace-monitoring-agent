local los = require('los')
local WindowsChecks = require('../check/windows').checks

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
end)

