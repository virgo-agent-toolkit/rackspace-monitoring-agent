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

local ZooKeeperCheck = require('monitoring/default/check').ZooKeeperCheck
local Metric = require('monitoring/default/check/base').Metric
local testUtil = require('monitoring/default/util/test')

local exports = {}

exports['test_zookeeper_success_result_parsing'] = function(test, asserts)
  local check = ZooKeeperCheck:new({id='foo', period=30, details={host='127.0.0.1', port=8585}})
  local filePath = path.join(process.cwd(), '/agents/monitoring/tests/fixtures/checks/zookeeper_response.txt')
  local commandMap = {}
  local server = nil

  commandMap['mntr\n'] = fs.readFileSync(filePath)

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

        asserts.ok(metrics['version']['v']:find('3.4.4--1') ~= -1)
        asserts.equal(metrics['open_file_descriptor_count']['v'], '33')
        asserts.equal(metrics['server_state']['v'], 'leader')
        asserts.equal(metrics['packets_received']['v'], '182451')
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

exports['test_zookeeper_empty_response'] = function(test, asserts)
  local check = ZooKeeperCheck:new({id='foo', period=30, details={host='127.0.0.1', port=8585}})
  local server = nil

  async.series({
    function(callback)
      testUtil.runTestTCPServer(8585, '127.0.0.1', {}, function(err, _server)
        server = _server
        callback(err)
      end)
    end,

    function(callback)
      check:run(function(result)
        local metrics = result:getMetrics()

        asserts.equal(#metrics, 0)
        asserts.equal(result:getState(), 'unavailable')

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

exports['test_zookeeper_connection_failure_error'] = function(test, asserts)
  local check = ZooKeeperCheck:new({id='foo', period=30, details={host='localhost', port=9098}})

  check:run(function(result)
    asserts.equal(result:getState(), 'unavailable')
    asserts.equal(result:getStatus(), 'ECONNREFUSED, connection refused')
    test.done()
  end)
end

return exports
