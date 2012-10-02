local FileSystemCheck = require('monitoring/default/check').FileSystemCheck

local exports = {}

exports['test_filesystem_check'] = function(test, asserts)
  local check = FileSystemCheck:new({id='foo', period=30})
  asserts.ok(check._lastResult == nil)
  check:run(function(result)
    local util = require('utils')
    local metrics = result:getMetrics()['/']

    asserts.not_nil(metrics['total']['v'])
    asserts.not_nil(metrics['free']['v'])
    asserts.not_nil(metrics['used']['v'])
    asserts.not_nil(metrics['avail']['v'])
    asserts.not_nil(metrics['files']['v'])
    asserts.not_nil(metrics['free_files']['v'])

    test.done()
  end)
end

return exports
