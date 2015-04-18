
local string = require('string')
local async = require('async')

local RedisCheck = require('../check').RedisCheck
local fixtures = require('./fixtures').checks
local testUtil = require('virgo/util/test')

require('../tap')(function(test)
  test('test redis 2.4 success result parsing', function(expect)
    local check = RedisCheck:new({id='foo', period=30, details={host='127.0.0.1', port=8585}})
    local commandMap = {}
    local server
    commandMap['INFO\r'] = fixtures["redis_2.4_response.txt"]
    async.series({
      function(callback)
        local function onServer(err, _server)
          server = _server
          callback(err)
        end
        testUtil.runTestTCPServer(8585, '127.0.0.1', commandMap, expect(onServer))
      end,
      function(callback)
        local function onResult(result)
          local metrics = result:getMetrics()['none']
          assert(result:getState() == 'available')
          assert(metrics['version']['v']:find('2.4') ~= nil)
          assert(metrics['version']['t'] == 'string')
          assert(metrics['used_memory']['v'] == '7126416')
          assert(metrics['used_memory']['t'] == 'uint64')
          assert(metrics['total_connections_received']['v'] == '1')
          assert(metrics['total_connections_received']['t'] == 'gauge')
          callback()
        end
        check:run(expect(onResult))
      end
    },
    function(err)
      if server then server:close() end
      assert(not err)
    end)
  end)

  test('test redis 2.6 success result parsing', function(expect)
    local check = RedisCheck:new({id='foo', period=30, details={host='127.0.0.1', port=8586}})
    local commandMap = {}
    local server
    commandMap['INFO\r'] = fixtures["redis_2.6_response.txt"]
    async.series({
      function(callback)
        local function onServer(err, _server)
          server = _server
          callback(err)
        end
        testUtil.runTestTCPServer(8586, '127.0.0.1', commandMap, expect(onServer))
      end,
      function(callback)
        local function onResult(result)
          local metrics = result:getMetrics()['none']
          assert(result:getState() == 'available')
          assert(metrics['version']['v']:find('2.5') ~= nil)
          assert(metrics['version']['t'] == 'string')
          assert(metrics['used_memory']['v'] == '528992')
          assert(metrics['used_memory']['t'] == 'uint64')
          assert(metrics['total_connections_received']['v'] == '1')
          assert(metrics['total_connections_received']['t'] == 'gauge')
          callback()
        end
        check:run(expect(onResult))
      end
    },
    function(err)
      if server then server:close() end
      assert(not err)
    end)
  end)

  test('test redis 2.4 success with auth', function(expect)
    local check = RedisCheck:new({id='foo', period=30, details={host='127.0.0.1', port=8585, password='valid'}})
    local server
    local commandMap = {}
    commandMap['AUTH valid\r'] = '+OK'
    commandMap['INFO\r'] = fixtures["redis_2.4_response.txt"]
    async.series({
      function(callback)
        local function onServer(err, _server)
          server = _server
          callback(err)
        end
        testUtil.runTestTCPServer(8585, '127.0.0.1', commandMap, expect(onServer))
      end,
      function(callback)
        local function onResult(result)
          local metrics = result:getMetrics()['none']
          assert(result:getState() == 'available')
          assert(metrics['version']['v']:find('2.4') ~= nil)
          assert(metrics['version']['t'] == 'string')
          assert(metrics['used_memory']['v'] == '7126416')
          assert(metrics['used_memory']['t'] == 'uint64')
          assert(metrics['total_connections_received']['v'] == '1')
          assert(metrics['total_connections_received']['t'] == 'gauge')
          callback()
        end
        check:run(expect(onResult))
      end
    },
    function(err)
      if server then server:close() end
      assert(not err)
    end)
  end)

  test('test redis error connection', function(expect)
    local function onResult(result)
      assert(result:getState() == 'unavailable')
    end
    local check = RedisCheck:new({id='foo', period=30, details={host='127.0.0.1', port=8113}})
    check:run(expect(onResult))
  end)

  test('test redis error missing password', function(expect)
    local check = RedisCheck:new({id='foo', period=30, details={host='127.0.0.1', port=8586}})
    local server
    local commandMap = {}
    commandMap['INFO\r'] = fixtures["redis_operation_not_permitted.txt"]
    async.series({
      function(callback)
        local function onServer(err, _server)
          server = _server
          callback(err)
        end
        testUtil.runTestTCPServer(8586, '127.0.0.1', commandMap, expect(onServer))
      end,
      function(callback)
        local function onResult(result)
          assert(result:getState() == 'unavailable')
          assert(result:getStatus() == 'Could not authenticate. Missing password?')
          callback()
        end
        check:run(expect(onResult))
      end
    },
    function(err)
      if server then server:close() end
      assert(not err)
    end)
  end)

  test('test redis error invalid password', function(expect)
    local check = RedisCheck:new({id='foo', period=30, details={host='127.0.0.1', port=8586, password='invalid'}})
    local server
    local commandMap = {}
    commandMap['AUTH invalid\r'] = fixtures["redis_invalid_password.txt"]
    async.series({
      function(callback)
        local function onServer(err, _server)
          server = _server
          callback(err)
        end
        testUtil.runTestTCPServer(8586, '127.0.0.1', commandMap, expect(onServer))
      end,
      function(callback)
        local function onResult(result)
          assert(result:getState() == 'unavailable')
          assert(result:getStatus() == 'Could not authenticate. Invalid password.')
          callback()
        end
        check:run(expect(onResult))
      end
    },
    function(err)
      if server then server:close() end
      assert(not err)
    end)
  end)

  test('test redis max line limit', function(expect)
    local check = RedisCheck:new({id='foo', period=30, details={host='127.0.0.1', port=8586, password='invalid'}})
    local server
    local commandMap = {}
    commandMap['AUTH invalid\r'] = function() return string.rep('a', 1024*1024*1 + 1) end
  
    async.series({
      function(callback)
        local function onServer(err, _server)
          server = _server
          callback(err)
        end
        testUtil.runTestTCPServer(8586, '127.0.0.1', commandMap, expect(onServer))
      end,
  
      function(callback)
        local function onResult(result)
          assert(result:getState() == 'unavailable')
          assert(result:getStatus() == 'Maximum buffer length reached')
          callback()
        end
        check:run(expect(onResult))
      end
    },
    function(err)
      if server then server:close() end
      assert(not err)
    end)
  end)

  test('test redis line endings', function(expect)
    local check = RedisCheck:new({id='foo', period=30, details={host='127.0.0.1', port=8587}})
    local server
    local commandMap = {}
    commandMap['INFO\r'] = function()
      return 'redis_version:2.5.7\r\n'
    end
  
    async.series({
      function(callback)
        local function onServer(err, _server)
          server = _server
          callback(err)
        end
        testUtil.runTestTCPServer(8587, '127.0.0.1', commandMap, expect(onServer))
      end,
      function(callback)
        local function onResult(result)
          local metrics = result:getMetrics()['none']
          assert(metrics.version.v == '2.5.7')
          callback()
        end
        check:run(expect(onResult))
      end
    },
    function(err)
      if server then server:close() end
      assert(not err)
  end)
  end)
end)
