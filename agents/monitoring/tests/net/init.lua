local table = require('table')
local async = require('async')
local ConnectionStream = require('monitoring/default/client/connection_stream').ConnectionStream
local helper = require('../helper')
local timer = require('timer')
local fixtures = require('../fixtures')
local constants = require('constants')
local Endpoint = require('../../default/endpoint').Endpoint

local exports = {}
local child

exports['test_reconnects'] = function(test, asserts)

  local options = {
    datacenter = 'test',
    stateDirectory = './tests',
    host = "127.0.0.1",
    port = 50061,
    tls = { rejectUnauthorized = false }
  }

  local client = ConnectionStream:new('id', 'token', 'guid', options)

  local clientEnd = 0
  local reconnect = 0

  client:on('client_end', function(err)
    clientEnd = clientEnd + 1
  end)

  client:on('reconnect', function(err)
    reconnect = reconnect + 1
  end)

  function counterTrigger(trigger, callback)
    local counter = 0
    return function()
      counter = counter + 1
      if counter == trigger then
        callback()
      end
    end
  end

  async.series({
    function(callback)
      child = helper.start_server(callback)
    end,
    function(callback)
      client:on('handshake_success', counterTrigger(3, callback))
      local endpoints = {}
      for _, address in pairs(fixtures.TESTING_AGENT_ENDPOINTS) do
        -- split ip:port
        table.insert(endpoints, Endpoint:new(address))
      end
      client:createConnections(endpoints, function() end)
    end,
    function(callback)
      helper.stop_server(child)
      client:on('reconnect', counterTrigger(3, callback))
    end,
    function(callback)
      child = helper.start_server(function()
        client:on('handshake_success', counterTrigger(3, callback))
      end)
    end,
  }, function()
    helper.stop_server(child)
    asserts.ok(clientEnd > 0)
    asserts.ok(reconnect > 0)
    test.done()
  end)
end

return exports
