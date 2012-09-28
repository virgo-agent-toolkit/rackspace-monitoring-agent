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

local async = require('async')

local RedisCheck = require('monitoring/default/check').RedisCheck
local testUtil = require('monitoring/default/util/test')

local exports = {}

exports['test_redis_2.4_success_result_parsing'] = function(test, asserts)
  local check = RedisCheck:new({id='foo', period=30, details={host='127.0.0.1', port=8585}})
  local filePath = path.join(process.cwd(), '/agents/monitoring/tests/fixtures/checks/redis_2.4_response.txt')
  local commandMap = {}
  local server = nil

  commandMap['INFO\r'] = fs.readFileSync(filePath)

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

        asserts.ok(metrics['redis_version']['v']:find('2.4') ~= nil)
        asserts.equal(metrics['redis_version']['t'], 'string')
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
  local filePath = path.join(process.cwd(), '/agents/monitoring/tests/fixtures/checks/redis_2.6_response.txt')
  local commandMap = {}
  local server = nil

  commandMap['INFO\r'] = fs.readFileSync(filePath)

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

        asserts.ok(metrics['redis_version']['v']:find('2.5') ~= nil)
        asserts.equal(metrics['redis_version']['t'], 'string')
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
  local filePath = path.join(process.cwd(), '/agents/monitoring/tests/fixtures/checks/redis_2.4_response.txt')
  local commandMap = {}
  local server = nil

  commandMap['AUTH valid\r'] = '+OK'
  commandMap['INFO\r'] = fs.readFileSync(filePath)

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

        asserts.ok(metrics['redis_version']['v']:find('2.4') ~= nil)
        asserts.equal(metrics['redis_version']['t'], 'string')
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
  local filePath = path.join(process.cwd(), '/agents/monitoring/tests/fixtures/checks/redis_operation_not_permitted.txt')
  local commandMap = {}
  local server = nil

  commandMap['INFO\r'] = fs.readFileSync(filePath)

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
  local filePath = path.join(process.cwd(), '/agents/monitoring/tests/fixtures/checks/redis_invalid_password.txt')
  local commandMap = {}
  local server = nil

  commandMap['AUTH invalid\r'] = fs.readFileSync(filePath)

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

return exports
