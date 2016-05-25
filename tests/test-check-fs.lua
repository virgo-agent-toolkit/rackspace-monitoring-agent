local los = require('los')
local env = require('env')
local path = require('path')
local FileSystemCheck = require('../check').FileSystemCheck

require('tap')(function(test)
  test('check filesystem valid', function(expect)
    local fs_target = '/'
    if los.type() == "win32" then fs_target = 'C:\\' end
    local onResult
    local check = FileSystemCheck:new({id='foo', period=30, details={target=fs_target}})
    assert(not check._lastResult)
    function onResult(result)
      local metrics = result:getMetrics()['none']
      assert(metrics['total']['v'])
      assert(metrics['free']['v'])
      assert(metrics['used']['v'])
      assert(metrics['avail']['v'])
  
      assert(metrics['total']['t'] == 'int64')
      assert(metrics['free']['t'] == 'int64')
      assert(metrics['used']['t'] == 'int64')
      assert(metrics['avail']['t'] == 'int64')
  
      assert(tonumber(metrics['free']['v']) <= tonumber(metrics['total']['v']))
      assert(tonumber(metrics['free']['v']) + tonumber(metrics['used']['v']) ==
                   tonumber(metrics['total']['v']))
  
      -- These metrics are unavailalbe on Win32, see:
      -- http://www.hyperic.com/support/docs/sigar/org/hyperic/sigar/FileSystemUsage.html#getFiles()
      if los.type() ~= "win32" then
        assert(metrics['files']['v'])
        assert(metrics['free_files']['v'])
        assert(metrics['files']['t'] == 'int64')
        assert(metrics['free_files']['t'] == 'int64')
        assert(tonumber(metrics['free_files']['v']) <= tonumber(metrics['files']['v']))
      end
    end
    check:run(expect(onResult))
  end)

  test('check filesystem valid proc mounts override', function(expect)
    local fs_target = '/'
    if los.type() == "win32" then return end
    local onResult
    local procTxt = path.join('tests', 'fixtures', 'procmounts.txt')
    env.set('TEST_PROC_MOUNTS', procTxt)
    local check = FileSystemCheck:new({id='foo', period=30, details={target=fs_target}})
    assert(not check._lastResult)
    function onResult(result)
      local metrics = result:getMetrics()['none']
      assert(metrics['total']['v'])
      assert(metrics['free']['v'])
      assert(metrics['used']['v'])
      assert(metrics['avail']['v'])
  
      assert(metrics['total']['t'] == 'int64')
      assert(metrics['free']['t'] == 'int64')
      assert(metrics['used']['t'] == 'int64')
      assert(metrics['avail']['t'] == 'int64')
      assert(metrics['options']['v']:find('hello_world') > 0)
  
      assert(tonumber(metrics['free']['v']) <= tonumber(metrics['total']['v']))
      assert(tonumber(metrics['free']['v']) + tonumber(metrics['used']['v']) ==
                   tonumber(metrics['total']['v']))
      assert(metrics['files']['v'])
      assert(metrics['free_files']['v'])
      assert(metrics['files']['t'] == 'int64')
      assert(metrics['free_files']['t'] == 'int64')
      assert(tonumber(metrics['free_files']['v']) <= tonumber(metrics['files']['v']))
      env.unset('TEST_PROC_MOUNTS')
    end
    check:run(expect(onResult))
  end)

  test('check filesystem non-existent mount point', function(expect)
    local check = FileSystemCheck:new({id='foo', period=30, details={target='does-not-exist'}})
    local function onResult(result)
      assert(result:getState() == 'unavailable')
      local expected_status = 'No filesystem mounted at does-not-exist'
      assert(result:getStatus():sub(1, expected_status:len()) == expected_status)
    end
    check:run(expect(onResult))
  end)

  test('check filesystem no mount point', function(expect)
    local check = FileSystemCheck:new({id='foo', period=30})
    local function onResult(result)
      assert(result:getState() == 'unavailable')
      local expected_status = 'Missing target parameter'
      assert(result:getStatus():sub(1, expected_status:len()) == expected_status)
    end
    check:run(expect(onResult))
  end)
end)

