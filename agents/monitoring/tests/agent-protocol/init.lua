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
local JSON = require('json')
local errors = require('monitoring/default/errors')
local Emitter = require('core').Emitter

local AgentProtocolConnection = require('monitoring/default/protocol/connection')
local loggingUtil = require ('monitoring/default/util/logging')
local instanceof = require('core').instanceof

local fixtures = require('../fixtures/protocol')

local exports = {}

exports['test_completion_key'] = function(test, asserts)
  local sock = Emitter:new()
  local conn = AgentProtocolConnection:new(loggingUtil.makeLogger(), 'MYID', 'TOKEN', sock)
  asserts.equals('MYID:1', conn:_completionKey('1'))
  asserts.equals('hello:1', conn:_completionKey('hello', '1'))
  test.done()
end

exports['test_bad_version_hello_gives_err'] = function(test, asserts)
  local sock = Emitter:new(), conn
  local data = fixtures['invalid-version']['handshake.hello.response']

  sock.write = function()
    sock:emit('data', data .. "\n")
  end

  conn = AgentProtocolConnection:new(loggingUtil.makeLogger(), 'MYID', 'TOKEN', sock)
  conn:on('error', function (err)
    asserts.equal(err.message, 'Version mismatch: message_version=1 response_version=2147483647')
  end)

  -- Ensure error is set
  conn:startHandshake(function(err, msg)
    asserts.ok(err)
    asserts.equals(msg.v, "2147483647")
    test.done()
  end)
end

function test_hello_response_error_handling(fixture, checkCb)
  return function(test, asserts)
    local sock = Emitter:new(), conn
    local data = fixtures[fixture]['handshake.hello.response']

    sock.write = function()
      sock:emit('data', data .. "\n")
    end

    conn = AgentProtocolConnection:new(loggingUtil.makeLogger(), 'MYID', 'TOKEN', sock)
    conn:on('error', checkCb(test, asserts))

    conn:startHandshake(function(err, msg)
      -- Ensure error is set
      asserts.ok(err)
      test.done()
    end)
  end
end

exports['test_bad_process_version_hello_fails'] = test_hello_response_error_handling('invalid-process-version', function(test, asserts)
  return function(err)
    asserts.ok(err.message:find('Agent version [%w%p]* is too old, please upgrade to'))
  end
end)

exports['test_bad_bundle_version_hello_fails'] = test_hello_response_error_handling('invalid-bundle-version', function(test, asserts)
  return function(err)
    asserts.ok(err.message:find('Agent bundle version [%w%p]* is too old, please upgrade to'))
  end
end)

exports['test_unexpected_response_and_hello_timeout'] = function(test, asserts)
  local sock = Emitter:new()
  local data = fixtures['invalid-version']['handshake.hello.response']
  local msg = JSON.parse(data)

  msg.id = 4

  data = fixtures.prepareJson(msg)
  sock.write = function()
    sock:emit('data', data .. "\n")
  end

  local conn = AgentProtocolConnection:new(loggingUtil.makeLogger(), 'MYID', 'TOKEN', sock)
  conn.HANDSHAKE_TIMEOUT = 30
  conn:on('error', function (err)
    p(err)
  end)

  -- Ensure error is set
  conn:startHandshake(function(err, msg)
    asserts.ok(instanceof(err, errors.ResponseTimeoutError))
    test.done()
  end)
end


exports['test_fragmented_message'] = function(test, asserts)
  local sock = Emitter:new(), conn
  local data = fixtures['handshake.hello.request']
  conn = AgentProtocolConnection:new(loggingUtil.makeLogger(), 'MYID', 'TOKEN', sock)
  conn:on('message', function(msg)
    asserts.equals(msg.target, 'endpoint')
    asserts.equals(msg.source, 'agentA')
    asserts.equals(msg.id, 0)
    asserts.equals(msg.params.token, 'MYTOKEN')
    test.done()
  end)
  sock:emit('data', data:sub(1, 4))
  sock:emit('data', data:sub(4, #data))
  sock:emit('data', "\n")
end

exports['test_multiple_messages_in_a_single_chunk'] = function(test, asserts)
  local sock = Emitter:new(), conn
  local messagesEmitted = 0

    conn = AgentProtocolConnection:new(loggingUtil.makeLogger(), 'MYID', 'TOKEN', sock)
    conn:on('message', function(msg)
      messagesEmitted = messagesEmitted + 1

      if messagesEmitted == 2 then
        test.done()
      end
    end)

    sock:emit('data', '{"v": "1", "id": 0, "target": "endpoint", "source": "X", "method": "handshake.hello", "params": { "token": "MYTOKEN", "agent_id": "MYUID" }}\n{"v": "1", "id": 0, "target": "endpoint", "source": "X", "method": "handshake.hello", "params": { "token": "MYTOKEN", "agent_id": "MYUID" }}\n')
end

return exports
