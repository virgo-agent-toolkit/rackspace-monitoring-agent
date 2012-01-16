local bourbon = require('bourbon')
local net = require('net')
local AgentProtocolServer = require('./agent-protocol-server')
local AgentClient = require('./agent-client')
local Timer = require('timer')

local exports = {}

local server
local PORT = 8080
local HOST = '127.0.0.1'

exports.setup = function(test)
  server = AgentProtocolServer.create(8080, host)
  test.done()
end

exports.teardown = function(test)
  server:close()
  test.done()
end

exports['test_blah'] = function(test, asserts)
  AgentClient.connect('1', HOST, PORT, function(err, client)
    asserts.assert(err == nil)
    client:simple_request("handshake.hello")
    client:on('message', function(message)
      asserts.assert(message)
      asserts.assert(message.id == 0)
      client:close()
      test.done()
    end)
  end)
end

local Test = {}
function Test.run()
  bourbon.run(exports)
end
return Test
