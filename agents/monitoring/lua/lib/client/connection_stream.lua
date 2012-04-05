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

--[[
Create and establish a connection to the multiple endpoints.

addresses - An Array of ip:port pairs
callback - Callback called with (err) when all the connections have been
established.
--]]
function ConnectionStream:createConnections(addresses, callback)
  local client

  async.forEach(addresses, function(address, callback)
    local client, split, host, port, options

    split = misc.splitAddress(address)
    options = {}
    options.host = split[1]
    options.port = split[2]
    options.datacenter = address
    client = self:createConnection(options, callback)
  end, callback)
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
  local previous_delay, delay, max_delay, jitter, value
  local datacenter = options.datacenter

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

  logging.log(logging.INFO, fmt('%s:%d -> Retrying connection in %dms', options.host, options.port, delay))
  timer.setTimeout(delay, function()
    self:createConnection(options, callback)
  end)
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
    err.host = host
    err.port = port
    err.datacenter = datacenter

    client:destroy()
    self:reconnect(opts, callback)
    if err then
      self:emit('error', err)
    end
  end)

  client:on('timeout', function()
    client:destroy()
    self:reconnect(opts, callback)
  end)

  client:on('end', function()
    logging.log(logging.DEBUG, fmt('%s:%d -> Remote endpoint closed the connection', host, port))
    client:destroy()
    self:reconnect(opts, callback)
  end)

  client:connect(function(err)
    if err then
      client:destroy()
      self:reconnect(opts, callback)
      callback(err)
      return
    end

    client.datacenter = datacenter
    self._clients[datacenter] = client

    -- TODO should do this after auth
    self._delays[datacenter] = 0
    callback();
  end)

  return client
end

local exports = {}
exports.ConnectionStream = ConnectionStream
return exports
