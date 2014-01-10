--[[
Copyright 2012 Rackspace
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]
local fs = require('fs')
local path = require('path')

local string = require('string')
local async = require('async')

local RedisCheck = require('/check').RedisCheck
local testUtil = require('/base/util/test')
local fixtures = require('/tests/fixtures').checks

local exports = {}

exports['test_redis_2.4_success_result_parsing'] = function(test, asserts)
  local check = RedisCheck:new({id='foo', period=30, details={host='127.0.0.1', port=8585}})
  local commandMap = {}
  local server = nil
  commandMap['INFO\r'] = fixtures["redis_2.4_response.txt"]
  async.series({
    function(callback)
      testUtil.runTestTCPServer(8585, '127.0.0.1', commandMap, function(err, _server)
        server = _server
        callback(err)
      end)
    end,
    function(callback)
      check:run(function(result)
        local metrics = result:getMetrics()['none']
        asserts.equal(result:getState(), 'available')
        asserts.ok(metrics['version']['v']:find('2.4') ~= nil)
        asserts.equal(metrics['version']['t'], 'string')
        asserts.equal(metrics['used_memory']['v'], '7126416')
        asserts.equal(metrics['used_memory']['t'], 'uint64')
        asserts.equal(metrics['total_connections_received']['v'], '1')
        asserts.equal(metrics['total_connections_received']['t'], 'gauge')
        callback()
      end)
    end
  },
  function(err)
    if server then
      server:close()
    end
    asserts.equals(err, nil)
    test.done()
  end)
end
exports['test_redis_2.6_success_result_parsing'] = function(test, asserts)
  local check = RedisCheck:new({id='foo', period=30, details={host='127.0.0.1', port=8586}})
  local commandMap = {}
  local server = nil
  commandMap['INFO\r'] = fixtures["redis_2.6_response.txt"]
  async.series({
    function(callback)
      testUtil.runTestTCPServer(8586, '127.0.0.1', commandMap, function(err, _server)
        server = _server
        callback(err)
      end)
    end,
    function(callback)
      check:run(function(result)
        local metrics = result:getMetrics()['none']
        asserts.equal(result:getState(), 'available')
        asserts.ok(metrics['version']['v']:find('2.5') ~= nil)
        asserts.equal(metrics['version']['t'], 'string')
        asserts.equal(metrics['used_memory']['v'], '528992')
        asserts.equal(metrics['used_memory']['t'], 'uint64')
        asserts.equal(metrics['total_connections_received']['v'], '1')
        asserts.equal(metrics['total_connections_received']['t'], 'gauge')
        callback()
      end)
    end
  },
  function(err)
    if server then
      server:close()
    end
    asserts.equals(err, nil)
    test.done()
  end)
end
exports['test_redis_2.4_success_with_auth'] = function(test, asserts)
  local check = RedisCheck:new({id='foo', period=30, details={host='127.0.0.1', port=8585, password='valid'}})
  local commandMap = {}
  local server = nil
  commandMap['AUTH valid\r'] = '+OK'
  commandMap['INFO\r'] = fixtures["redis_2.4_response.txt"]
  async.series({
    function(callback)
      testUtil.runTestTCPServer(8585, '127.0.0.1', commandMap, function(err, _server)
        server = _server
        callback(err)
      end)
    end,
    function(callback)
      check:run(function(result)
        local metrics = result:getMetrics()['none']
        asserts.equal(result:getState(), 'available')
        asserts.ok(metrics['version']['v']:find('2.4') ~= nil)
        asserts.equal(metrics['version']['t'], 'string')
        asserts.equal(metrics['used_memory']['v'], '7126416')
        asserts.equal(metrics['used_memory']['t'], 'uint64')
        asserts.equal(metrics['total_connections_received']['v'], '1')
        asserts.equal(metrics['total_connections_received']['t'], 'gauge')
        callback()
      end)
    end
  },
  function(err)
    if server then
      server:close()
    end
    asserts.equals(err, nil)
    test.done()
  end)
end
exports['test_redis_error_connection'] = function(test, asserts)
  local check = RedisCheck:new({id='foo', period=30, details={host='127.0.0.1', port=8113}})
  check:run(function(result)
    asserts.equal(result:getState(), 'unavailable')
    asserts.equal(result:getStatus(), 'ECONNREFUSED, connection refused')
    test.done()
  end)
end
exports['test_redis_error_missing_password'] = function(test, asserts)
  local check = RedisCheck:new({id='foo', period=30, details={host='127.0.0.1', port=8586}})
  local commandMap = {}
  local server = nil
  commandMap['INFO\r'] = fixtures["redis_operation_not_permitted.txt"]
  async.series({
    function(callback)
      testUtil.runTestTCPServer(8586, '127.0.0.1', commandMap, function(err, _server)
        server = _server
        callback(err)
      end)
    end,
    function(callback)
      check:run(function(result)
        local metrics = result:getMetrics()['none']
        asserts.equal(result:getState(), 'unavailable')
        asserts.equal(result:getStatus(), 'Could not authenticate. Missing password?')
        callback()
      end)
    end
  },
  function(err)
    if server then
      server:close()
    end
    asserts.equals(err, nil)
    test.done()
  end)
end
exports['test_redis_error_invalid_password'] = function(test, asserts)
  local check = RedisCheck:new({id='foo', period=30, details={host='127.0.0.1', port=8586, password='invalid'}})
  local commandMap = {}
  local server = nil
  commandMap['AUTH invalid\r'] = fixtures["redis_invalid_password.txt"]
  async.series({
    function(callback)
      testUtil.runTestTCPServer(8586, '127.0.0.1', commandMap, function(err, _server)
        server = _server
        callback(err)
      end)
    end,
    function(callback)
      check:run(function(result)
        local metrics = result:getMetrics()['none']
        asserts.equal(result:getState(), 'unavailable')
        asserts.equal(result:getStatus(), 'Could not authenticate. Invalid password.')
        callback()
      end)
    end
  },
  function(err)
    if server then
      server:close()
    end
    asserts.equals(err, nil)
    test.done()
  end)
end

exports['test_redis_max_line_limit'] = function(test, asserts)
  local check = RedisCheck:new({id='foo', period=30, details={host='127.0.0.1', port=8586, password='invalid'}})
  local commandMap = {}
  local longString = string.rep('a', 1024*1024*1 + 1)
  local server = nil

  commandMap['AUTH invalid\r'] = function()
    return longString
  end

  async.series({
    function(callback)
      testUtil.runTestTCPServer(8586, '127.0.0.1', commandMap, function(err, _server)
        server = _server
        callback(err)
      end)
    end,

    function(callback)
      check:run(function(result)
        local metrics = result:getMetrics()['none']

        asserts.equal(result:getState(), 'unavailable')
        asserts.equal(result:getStatus(), 'Maximum buffer length reached')

        callback()
      end)
    end
  },

  function(err)
    if server then
      server:close()
    end

    asserts.equals(err, nil)
    test.done()
  end)
end

exports['test_redis_line_endings'] = function(test, asserts)
  local check = RedisCheck:new({id='foo', period=30, details={host='127.0.0.1', port=8587}})
  local commandMap = {}
  local server = nil

  commandMap['INFO\r'] = function()
    return 'redis_version:2.5.7\r\n'
  end

  async.series({
    function(callback)
      testUtil.runTestTCPServer(8587, '127.0.0.1', commandMap, function(err, _server)
        server = _server
        callback(err)
      end)
    end,

    function(callback)
      check:run(function(result)
        local metrics = result:getMetrics()['none']
        asserts.equal(metrics.version.v, '2.5.7')
        callback()
      end)
    end
  },

  function(err)
    if server then
      server:close()
    end

    asserts.equals(err, nil)
    test.done()
  end)
end

return exports
