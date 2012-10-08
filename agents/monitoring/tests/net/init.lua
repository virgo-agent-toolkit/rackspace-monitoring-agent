local async = require('async')
local ConnectionStream = require('monitoring/default/client/connection_stream').ConnectionStream
local helper = require('../helper')
local timer = require('timer')
local fixtures = require('../fixtures')
local constants = require('constants')

local exports = {}
local child

local function start_server(callback)
  local data = ''
  child = helper.runner('server_fixture_blocking')
  child.stderr:on('data', function(d)
    callback(d)
    callback = nil
  end)
  child.stdout:on('data', function(chunk)
    data = data .. chunk
    if data:find('TLS fixture server listening on port 50061') and callback then
      callback()
      callback = nil
      return
    end
  end)
end

local function stop_server(callback)
  if child then
    child:kill(constants.SIGUSR1) -- USR1
    child = nil
  end
  if callback then
    callback()
  end
end

process:on('exit', function()
  stop_server()
end)

exports['test_reconnects'] = function(test, asserts)

  local options = {
    datacenter = 'test',
    tls = { rejectUnauthorized = false },
    stateDirectory = './tests'
  }
  local client = ConnectionStream:new('id', 'token', 'guid', options)

  local errorCount = 0
  client:on('error', function(err)
    errorCount = errorCount + 1
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
    start_server,
    function(callback)
      client:on('handshake_success', counterTrigger(3, callback))
      client:createConnections(fixtures.TESTING_AGENT_ENDPOINTS, function() end)
    end,
    function(callback)
      stop_server(function()
        client:on('reconnect', counterTrigger(3, callback))
      end)
    end,
    function(callback)
      start_server(function()
        client:on('handshake_success', counterTrigger(3, callback))
      end)
    end,
  }, function()
    asserts.ok(errorCount > 0)
    test.done()
  end)
end

return exports
