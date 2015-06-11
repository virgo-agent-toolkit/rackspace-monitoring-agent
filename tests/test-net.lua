--[[
Copyright 2015 Rackspace

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

require('tap')(function(test)

  local server = require('./server')
  local Endpoint = require('virgo/client/endpoint').Endpoint
  local ConnectionStream = require('virgo/client/connection_stream').ConnectionStream
  local async = require('async')
  local constants = require('../constants')
  local los = require('los')
  local misc = require('virgo/util/misc')
  local timer = require('timer')

  -----------------------------------------------------------------------------

  local TimeoutServer = server.Server:extend()
  function TimeoutServer:initialize(options)
    server.Server.initialize(self, options)
  end

  function TimeoutServer:_onLineProtocol(client, line)
    -- Timeout All Requests
  end

  -----------------------------------------------------------------------------

  server.opts.destroy_connection_base = 200
  server.opts.destroy_connection_jitter = 200

  constants:setGlobal('DATACENTER_FIRST_RECONNECT_DELAY', 3000)
  constants:setGlobal('DATACENTER_FIRST_RECONNECT_DELAY_JITTER', 0)
  constants:setGlobal('DATACENTER_RECONNECT_DELAY', 3000)
  constants:setGlobal('DATACENTER_RECONNECT_DELAY_JITTER', 0)
  constants:setGlobal('DEFAULT_HANDSHAKE_TIMEOUT', 10000)

  -----------------------------------------------------------------------------

  test('test handshake timeout', function()
    local options = {
      datacenter = 'test',
      tls = { rejectUnauthorized = false }
    }
    local client = ConnectionStream:new('id', 'token', 'guid', false, options)
    local endpoints = { Endpoint:new('127.0.0.1:4444') }
    local AEP = TimeoutServer:new({ includeTimeouts = false })
    AEP:listen(4444, '127.0.0.1')

    async.series({
      function(callback)
        client:createConnections(endpoints, callback)
      end,
      function(callback)
        client:once('reconnect', callback)
      end
    }, function()
      AEP:close()
      client:shutdown()
    end)
  end)

  test('test reconnects', function()
    local options = {
      datacenter = 'test',
      tls = { rejectUnauthorized = false }
    }
    local client = ConnectionStream:new('id', 'token', 'guid', false, options)
    local clientEnd = 0
    local reconnect = 0

    client:on('client_end', function(err)
      clientEnd = clientEnd + 1
    end)

    client:on('reconnect', function(err)
      reconnect = reconnect + 1
    end)

    local endpoints = { Endpoint:new('127.0.0.1:4444')}
    local AEP = server.Server:new({ includeTimeouts = false })
    AEP:listen(4444, '127.0.0.1')

    async.series({
      function(callback)
        client:once('handshake_success', callback)
        client:createConnections(endpoints, function() end)
      end,
      function(callback)
        AEP:close()
        timer.setImmediate(function()
          AEP = server.Server:new({ includeTimeouts = false })
          AEP:listen(4444, '127.0.0.1')
        end)
        client:once('reconnect', callback)
      end,
      function(callback)
        client:once('handshake_success', callback)
      end,
    }, function()
      client:shutdown()
      AEP:close()
    end)
  end)
end)
