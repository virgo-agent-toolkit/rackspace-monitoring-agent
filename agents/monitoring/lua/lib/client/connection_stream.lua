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
local ConnectionMessages = require('./connection_messages').ConnectionMessages
local logging = require('logging')
local misc = require('../util/misc')

local fmt = require('string').format

local CONNECT_TIMEOUT = 6000

local ConnectionStream = Emitter:extend()
function ConnectionStream:initialize(id, token)
  self._id = id
  self._token = token
  self._clients = {}
  self._unauthedClients = {}
  self._delays = {}
  self._messages = ConnectionMessages:new(self)
end

--[[
Create and establish a connection to the multiple endpoints.

addresses - An Array of ip:port pairs
callback - Callback called with (err) when all the connections have been
established.
--]]
function ConnectionStream:createConnections(addresses, callback)
  async.series({
    -- connect
    function(callback)
      async.forEach(addresses, function(address, callback)
        local split, client, options
        split = misc.splitAddress(address)
        options = {}
        options.host = split[1]
        options.port = split[2]
        options.datacenter = address
        self:createConnection(options, callback)
      end)
    end
  }, callback)
end

function ConnectionStream:_setDelay(datacenter)
  local maxDelay = 5 * 60 * 1000 -- max connection delay in ms
  local jitter = 7000 -- jitter in ms
  local previousDelay = self._delays[datacenter]
  local delay

  if previousDelay == nil then
    self._delays[datacenter] = 0
    previousDelay = 0
  end

  delay = math.min(previousDelay, maxDelay) + (jitter * math.random())
  self._delays[datacenter] = delay

  return delay
end

--[[
Retry a connection to the endpoint.

options - datacenter, host, port
  datacenter - Datacenter name / host alias.
  host - Hostname.
  port - Port.
callback - Callback called with (err)
]]--
function ConnectionStream:reconnect(options, callback)
  local datacenter = options.datacenter
  local delay = self:_setDelay(datacenter)

  logging.log(logging.INFO, fmt('%s:%d -> Retrying connection in %dms', options.host, options.port, delay))
  timer.setTimeout(delay, function()
    self:createConnection(options, callback)
  end)
end

function ConnectionStream:getClient()
  local client, min_latency, latency
  for k, v in pairs(self._clients) do
    latency = self._clients[k]:getLatency()
    if client == nil or min_latency > latency then
      client = self._clients[k]
    end
    min_latency = latency
  end
  return client
end

--[[
Move an unauthenticated client to the list of clients that have been authenticated.
client - the client.
]]--
function ConnectionStream:_promoteClient(client)
  local datacenter = client:getDatacenter()
  client:log(logging.INFO, fmt('Connection has been authenticated to %s', datacenter))
  self._clients[datacenter] = client
  self._unauthedClients[datacenter] = nil
end

--[[
Create and establish a connection to the endpoint.

datacenter - Datacenter name / host alias.
host - Hostname.
port - Port.
callback - Callback called with (err)
]]--
function ConnectionStream:createConnection(options, callback)
  local opts = misc.merge({
    id = self._id,
    token = self._token,
    timeout = CONNECT_TIMEOUT
  }, options)

  local client = AgentClient:new(opts)
  client:on('error', function(err)
    err.host = opts.host
    err.port = opts.port
    err.datacenter = opts.datacenter

    client:destroy()
    self:reconnect(opts, callback)
    if err then
      self:emit('error', err)
    end
  end)

  client:on('timeout', function()
    logging.log(logging.DEBUG, fmt('%s:%d -> Client Timeout', opts.host, opts.port))
    client:destroy()
    self:reconnect(opts, callback)
  end)

  client:on('end', function()
    self:emit('client_end', client)
    logging.log(logging.DEBUG, fmt('%s:%d -> Remote endpoint closed the connection', opts.host, opts.port))
    client:destroy()
    self:reconnect(opts, callback)
  end)

  client:on('handshake_success', function()
    self:_promoteClient(client)
    self._delays[options.datacenter] = 0
    client:startPingInterval()
    self._messages:emit('handshake_success', client)
  end)

  client:on('message', function(msg)
    self._messages:emit('message', client, msg)
  end)

  client:connect(function(err)
    if err then
      client:destroy()
      self:reconnect(opts, callback)
      callback(err)
      return
    end

    client.datacenter = datacenter
    self._unauthedClients[datacenter] = client

    callback();
  end)

  return client
end

local exports = {}
exports.ConnectionStream = ConnectionStream
return exports
