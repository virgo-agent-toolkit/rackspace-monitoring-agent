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
  local once = false
  child = helper.runner('server_fixture_blocking')
  child.stdout:on('data', function(chunk)
    data = data .. chunk
    if data:find('TCP echo server listening on port 50061') then
      if once == false then
        once = true
        callback()
      end
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
    tls = { rejectUnauthorized = false }
  }
  local client = ConnectionStream:new('id', 'token', options)

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
      start_server(function()
        timer.setTimeout(2000, callback)
      end)
    end,
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
    test.done()
  end)
end

return exports
