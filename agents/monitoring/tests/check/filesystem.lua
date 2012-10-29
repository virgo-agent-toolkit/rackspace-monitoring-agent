local math = require('math')

local FileSystemCheck = require('monitoring/default/check').FileSystemCheck

local exports = {}

exports['test_filesystem_check'] = function(test, asserts)
  local check = FileSystemCheck:new({id='foo', period=30, details={target='/'}})
  asserts.ok(check._lastResult == nil)
  check:run(function(result)
    local util = require('utils')
    local metrics = result:getMetrics()['none']

    asserts.not_nil(metrics['total']['v'])
    asserts.not_nil(metrics['free']['v'])
    asserts.not_nil(metrics['used']['v'])
    asserts.not_nil(metrics['avail']['v'])
    asserts.not_nil(metrics['files']['v'])
    asserts.not_nil(metrics['free_files']['v'])

    asserts.equal(metrics['total']['t'], 'int64')
    asserts.equal(metrics['free']['t'], 'int64')
    asserts.equal(metrics['used']['t'], 'int64')
    asserts.equal(metrics['avail']['t'], 'int64')
    asserts.equal(metrics['files']['t'], 'int64')
    asserts.equal(metrics['free_files']['t'], 'int64')

    asserts.ok(tonumber(metrics['free']['v']) <= tonumber(metrics['total']['v']))
    asserts.ok(tonumber(metrics['free_files']['v']) <= tonumber(metrics['files']['v']))
    asserts.equal(tonumber(metrics['free']['v']) + tonumber(metrics['used']['v']),
                 tonumber(metrics['total']['v']))

    asserts.equal(math.floor((tonumber(metrics['avail']['v']) / tonumber(metrics['total']['v'])) * 100),
                 math.floor(tonumber(metrics['free_percent']['v'])))
    asserts.equal(math.floor((tonumber(metrics['used']['v']) / tonumber(metrics['total']['v'])) * 100),
                 math.floor(tonumber(metrics['used_percent']['v'])))

    test.done()
  end)
end

return exports
