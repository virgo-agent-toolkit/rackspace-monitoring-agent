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

local AgentProtocol = require('monitoring/lib/protocol/protocol').AgentProtocol
local AgentProtocolConnection = require('monitoring/lib/protocol/connection')
local loggingUtil = require ('monitoring/lib/util/logging')

local exports = {}

exports['test_handshake_hello'] = function(test, asserts)
  fs.readFile('./agents/monitoring/tests/agent-protocol/handshake.hello.request.json', function(err, data)
    if (err) then
      p(err)
      asserts.is_nil(err)
      return
    end
    local hello = { }
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
    asserts.equals(response.target, "X")
    asserts.equals(response.result, nil)
    test.done()
  end)
end

exports['test_fragmented_message'] = function(test, asserts)
  local sock = Emitter:new(), conn
  fs.readFile('./agents/monitoring/tests/agent-protocol/handshake.hello.request.json', function(err, data)
    if (err) then
      p(err)
      asserts.is_nil(err)
      return
    end
    conn = AgentProtocolConnection:new(loggingUtil.makeLogger(), 'MYID', 'TOKEN', sock)
    conn:on('message', function(msg)
      asserts.equals(msg.target, 'endpoint')
      asserts.equals(msg.source, 'X')
      asserts.equals(msg.id, 0)
      asserts.equals(msg.params.token, 'MYTOKEN')
      test.done()
    end)
    sock:emit('data', data:sub(1, 4))
    sock:emit('data', data:sub(4, #data))
  end)
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
