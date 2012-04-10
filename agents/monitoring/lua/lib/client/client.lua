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
local tls = require('tls')
local timer = require('timer')
local Error = require('core').Error
local Object = require('core').Object
local Emitter = require('core').Emitter
local check = require('../check')
local logging = require('logging')
local misc = require('../util/misc')
local loggingUtil = require ('../util/logging')
local AgentProtocolConnection = require('../protocol/connection')
local table = require('table')

local fmt = require('string').format

local AgentClient = Emitter:extend()

local PING_INTERVAL = 5 * 60 * 1000 -- ms

function AgentClient:initialize(options)--datacenter, id, token, host, port, timeout)

  self.protocol = nil
  self._datacenter = options.datacenter
  self._id = options.id
  self._token = options.token
  self._target = 'endpoint'
  self._host = options.host
  self._port = options.port
  self._timeout = options.timeout or 5000

  self._scheduler = nil
  self._ping_interval = nil
  self._sent_ping_count = 0
  self._got_pong_count = 0
  self._latency = 0

  self._log = loggingUtil.makeLogger(fmt('%s:%s', self._host, self._port))
end

function AgentClient:getDatacenter()
  return self._datacenter
end

function AgentClient:_createChecks(manifest)
  local checks = {}

  for i, _ in ipairs(manifest.checks) do
    local check = check.create(manifest.checks[i])
    if check then
      self._log(logging.INFO, 'Created Check: ' .. check:toString())
      table.insert(checks, check)
    end
  end

  return checks
end

function AgentClient:getLog()
  return self._log
end

function AgentClient:_socketTimeout()
  return misc.calcJitter(PING_INTERVAL, 19000)
end

function AgentClient:connect()
  -- Create connection timeout
  self._log(logging.INFO, 'Connecting...')
  self._sock = tls.connect(self._port, self._host, {}, function(err, cleartext)
    -- Log
    self._log(logging.INFO, 'Connected')

    -- setup protocol
    self.protocol = AgentProtocolConnection:new(self._log, self._id, self._token, cleartext)
    self.protocol:on('error', function(err)
      self:emit(err)
    end)
    -- response to messages
    self.protocol:on('message', function(msg)
      self:emit('message', msg, self)
      self.protocol:execute(msg)
    end)

    -- begin handshake
    self.protocol:startHandshake(function(err, msg)
      if err then
        self:emit('error', err)
      else
        self._ping_interval = msg.result.ping_interval
        self:startPingInterval()

        self:emit('handshake_success')
      end
    end)
  end)
  self._log(logging.DBG, fmt('Using timeout %sms', self:_socketTimeout()))
  self._sock.socket:setTimeout(self:_socketTimeout(), function()
    self:emit('timeout')
  end)
  self._sock:on('error', function(err)
    self._log(logging.ERROR, fmt('Failed to connect: %s', err.message))
    self:emit('error', err)
  end)
  self._sock:on('end', function()
    self:emit('end')
  end)
end

function AgentClient:getLatency()
  return self._latency
end

function AgentClient:startPingInterval()
  function startInterval()
    local timeout = misc.calcJitter(self._ping_interval, 7000)

    self._log(logging.DEBUG, fmt('Starting ping interval, interval=%dms', self._ping_interval))

    self._pingTimeout = timer.setTimeout(timeout, function()
      local timestamp = os.time()

      self._log(logging.DEBUG, fmt('Sending ping (timestamp=%d,sent_ping_count=%d,got_pong_count=%d)',
                                    timestamp, self._sent_ping_count, self._got_pong_count))
      self._sent_ping_count = self._sent_ping_count + 1
      self.protocol:sendPing(timestamp, function(err, msg)
        if err then
          self._log(logging.DEBUG, 'Got an error while sending ping: ' .. tostring(err))
          return
        end

        if msg.result.timestamp then
          self._got_pong_count = self._got_pong_count + 1
          self._log(logging.DEBUG, fmt('Got pong (sent_ping_count=%d,got_pong_count=%d)',
                                       self._sent_ping_count, self._got_pong_count))
        else
          self._log(logging.DEBUG, 'Got invalid pong response')
        end

        self._latency = os.time() - timestamp

        startInterval()
      end)
    end)
   end

   startInterval()
end

function AgentClient:clearPingInterval()
  if self._pingTimeout then
    self._log(logging.DEBUG, 'Clearing ping interval')
    timer.clearTimer(self._pingTimeout)
    self._pingTimeout = nil
  end
end

function AgentClient:destroy()
  self:clearPingInterval()

  if self._sock then
    self._log(logging.DEBUG, 'Closing socket')
    self._sock:destroy()
    self._sock = nil
  end
end

local exports = {}
exports.AgentClient = AgentClient
return exports
