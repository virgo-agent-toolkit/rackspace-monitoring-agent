local fs = require('fs')
local JSON = require('json')
local Emitter = require('core').Emitter

local AgentProtocol = require('monitoring/lib/protocol/protocol').AgentProtocol
local AgentProtocolConnection = require('monitoring/lib/protocol/connection')

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
    conn = AgentProtocolConnection:new('MYID', 'TOKEN', sock)
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

return exports
