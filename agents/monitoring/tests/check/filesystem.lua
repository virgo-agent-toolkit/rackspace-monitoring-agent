local math = require('math')
local os = require('os')

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

    test.done()
  end)
end

exports['test_filesystem_check_nonexistent_mount_point'] = function(test, asserts)
  local check = FileSystemCheck:new({id='foo', period=30, details={target='does-not-exist'}})
  check:run(function(result)
    asserts.equal(result:getState(), 'unavailable')
    asserts.equal(result:getStatus(), 'No filesystem mounted at does-not-exist')
    test.done()
  end)
end

exports['test_filesystem_check_no_mount_point'] = function(test, asserts)
  local check = FileSystemCheck:new({id='foo', period=30})
  check:run(function(result)
    asserts.equal(result:getState(), 'unavailable')
    asserts.equal(result:getStatus(), 'Missing target parameter')
    test.done()
  end)
end

-- This will skip all the functions in the file but still call them individually
if os.type() == "win32" then
  for i,v in pairs(exports) do
    p("Setting a skip " .. i .. " for " .. os.type())
    exports[i] = function(test, asserts)
      test.skip("Skipping " .. i .. " for " .. os.type())
    end
  end
end

return exports
