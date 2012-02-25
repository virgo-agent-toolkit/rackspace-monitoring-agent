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

local os = require('os')
local net = require('net')
local timer = require('timer')
local Error = require('core').Error
local Object = require('core').Object
local Emitter = require('core').Emitter
local logging = require('logging')
local AgentProtocolConnection = require('../protocol/connection')

local fmt = require('string').format

local AgentClient = Emitter:extend()

local PING_INTERVAL = 5 * 60 * 1000-- ms
local PING_INTERVAL = 4000

function AgentClient:initialize(datacenter, id, token, host, port, timeout)
  self.protocol = nil
  self._datacenter = datacenter
  self._id = id
  self._token = token
  self._target = 'endpoint'
  self._sock = nil
  self._host = host
  self._port = port
  self._timeout = timeout or 5000

  self._sent_ping_count = 0
  self._got_pong_count = 0
end

function AgentClient:connect()
  -- Create connection timeout
  local connectTimeout = timer.setTimeout(self._timeout, function()
    logging.log(logging.ERROR, fmt('Failed to connect to %s:%d: timeout', self._host, self._port))

    self:emit('error', Error:new(fmt('Connect timeout to %s:%s', self._host, self._port)))
  end)

  logging.log(logging.INFO, fmt('Connecting to %s:%s', self._host, self._port))
  self._sock = net.createConnection(self._port, self._host, function()
    -- stop the timeout timer since there is a connect
    timer.clearTimer(connectTimeout);
    connectTimeout = nil

    -- Log
    logging.log(logging.INFO, fmt('Connected to %s:%s', self._host, self._port))

    -- setup protocol and begin handshake
    self.protocol = AgentProtocolConnection:new(self._id, self._token, self._sock)
    self.protocol:startHandshake(function(err, msg)
      if not err then
        self:startPingInterval()
      end
    end)
  end)
  self._sock:on('error', function(err)
    logging.log(logging.ERROR, fmt('Failed to connect to %s:%d: %s', self._host, self._port, tostring(err)))

    if connectTimeout then
      timer.clearTimer(connectTimeout);
    end
    self:emit('error', err)
  end)
  self._sock:on('end', function()
    self:emit('end')
  end)
end

function AgentClient:startPingInterval()
  logging.log(logging.DEBUG, fmt('Starting ping interval, interval=%dms', PING_INTERVAL))

  function startInterval()
    self._pingTimeout = timer.setTimeout(PING_INTERVAL, function()
      local timestamp = os.time()

      logging.log(logging.DEBUG, fmt('Sending ping to %s:%d (timestamp=%d,sent_ping_count=%d,got_pong_count=%d)',
                                     self._host, self._port, timestamp, self._sent_ping_count, self._got_pong_count))
      self._sent_ping_count = self._sent_ping_count + 1
      self.protocol:sendPing(timestamp, function(err, msg)
        if msg.result.timestamp then
          logging.log(logging.DEBUG, fmt('Got pong from %s:%d', self._host, self._port))
          self._got_pong_count = self._got_pong_count + 1
        else
          logging.log(logging.DEBUG, fmt('Got invalid pong response from %s:%d', self._host, self._port))
        end

        startInterval()
      end)
    end)
   end

   startInterval()
end

function AgentClient:close()
  if self._pingTimeout then
    logging.log(logging.DEBUG, 'Clearing ping interval')
    timer.clearTimer(self._pingTimeout)
  end

  if self._sock then
    logging.log(logging.DEBUG, 'Closing socket')
    self._sock:close()
  end
end

local exports = {}
exports.AgentClient = AgentClient
return exports
