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

local Emitter = require('core').Emitter
local math = require('math')
local timer = require('timer')
local fmt = require('string').format

local async = require('async')

local AgentClient = require('./client').AgentClient
local logging = require('logging')
local misc = require('../util/misc')

local CONNECT_TIMEOUT = 6000

local ConnectionStream = Emitter:extend()
function ConnectionStream:initialize(id, token)
  self._id = id
  self._token = token
  self._clients = {}
  self._delays = {}
end

-- Create connection to the multiple endpoints.
--
-- addresses - An Array of ip:port pairs
-- callback - Callback which is called when all the connections have been
-- established.
function ConnectionStream:createConnections(addresses, callback)
  local client, clients = {}

  async.forEach(addresses, function(address, callback)
    local client, split, host, port

    split = misc.splitAddress(address)
    host, port = split[1], split[2]
    client = self:createConnection(address, host, port, callback)
  end, callback)
end

-- Retry a connection to the endpoint.
function ConnectionStream:reconnect(datacenter, host, port, callback)
  local previous_delay, delay, max_delay, jitter, value

  max_delay = 5 * 60 * 1000 -- max connection delay in ms
  jitter = 7000 -- jitter in ms

  previous_delay = self._delays[datacenter]

  -- First reconnection attempt
  if self._delays[datacenter] == nil then
    self._delays[datacenter] = 0
    previous_delay = 0
  end

  delay = math.min(previous_delay, max_delay) + (jitter * math.random())
  self._delays[datacenter] = delay

  logging.log(logging.INFO, fmt('Retrying connection to %s (%s:%d) in %dms', datacenter, host, port, delay))
  timer.setTimeout(delay, function()
    self:createConnection(datacenter, host, port, callback)
  end)
end

-- Create a connection to the endpoint.
function ConnectionStream:createConnection(datacenter, host, port, callback)
  local client = AgentClient:new(datacenter, self._id, self._token, host, port, CONNECT_TIMEOUT)

  client:on('error', function(err)
    err.host = host
    err.port = port
    err.datacenter = datacenter

    self:reconnect(datacenter, host, port, callback)
    self:emit('error', err)
  end)
  client:connect(function(err)
    if err then
      self:reconnect(datacenter, host, port, callback)
      callback(err)
      return
    end
    client.datacenter = datacenter
    self._clients[datacenter] = client
    callback();
  end)
  return client
end

local exports = {}
exports.ConnectionStream = ConnectionStream
return exports
