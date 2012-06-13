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
local Emitter = require('core').Emitter

local AgentProtocol = require('monitoring/default/protocol/protocol').AgentProtocol
local AgentProtocolConnection = require('monitoring/default/protocol/connection')
local loggingUtil = require ('monitoring/default/util/logging')

local fixtures = require('../fixtures/protocol')

local exports = {}

exports['test_completion_key'] = function(test, asserts)
  local data = fixtures['handshake.hello.request']
  local sock = Emitter:new()
  local conn = AgentProtocolConnection:new(loggingUtil.makeLogger(), 'MYID', 'TOKEN', sock)
  asserts.equals('MYID:1', conn:_completionKey('1'))
  asserts.equals('hello:1', conn:_completionKey('hello', '1'))
  test.done()
end

exports['test_handshake_hello'] = function(test, asserts)
  local hello = { }
  local data = fixtures['handshake.hello.request']
  hello.data = JSON.parse(data)
  hello.write = function(_, res)
    hello.res = res
  end
  local agent = AgentProtocol:new(hello.data, hello)
  agent:request(hello.data)
  response = JSON.parse(hello.res)

  -- TODO: asserts.object_equals in bourbon
  asserts.equals(response.v, 1)
  asserts.equals(response.id, 1)
  asserts.equals(response.source, "endpoint")
  asserts.equals(response.target, "agentA")
  asserts.equals(response.result, nil)
  test.done()
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
