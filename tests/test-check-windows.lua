local los = require('los')
local WindowsChecks = require('../check/windows').checks

require('../tap')(function(test)
  test('test check windows perfos', function(expect)
    local check = WindowsChecks.WindowsPerfOSCheck:new({id='foo', period=30})
    assert(check._lastResult == nil)
    local function onResult(result)
      assert(result)
      assert(check._lastResult)
      if los.type() == 'win32' then
        assert(result:getStatus(), 'success')
        assert(#check._lastResult:serialize() > 0)
        local metrics = result:getMetrics()['none']
        assert(metrics['Processes']['t'] == 'uint32')
        -- Values always become strings internally
        assert(tonumber(metrics['Processes']['v']) > 0)
      else
        assert(result:getStatus() ~= 'success')
      end
    end
    check:run(expect(onResult))
  end)

end)
