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
local dns = require('dns')

local Scheduler = require('../schedule').Scheduler
local AgentClient = require('./client').AgentClient
local ConnectionMessages = require('./connection_messages').ConnectionMessages
local logging = require('logging')
local consts = require('../util/constants')
local misc = require('../util/misc')
local vtime = require('virgo-time')
local path = require('path')

local ConnectionStream = Emitter:extend()
function ConnectionStream:initialize(id, token, guid, options)
  self._id = id
  self._token = token
  self._guid = guid
  self._clients = {}
  self._unauthedClients = {}
  self._delays = {}
  self._messages = ConnectionMessages:new(self)
  self._activeTimeSyncClient = nil
  self._options = options or {}
end

--[[
Create and establish a connection to the multiple endpoints.

addresses - An Array of ip:port pairs
callback - Callback called with (err) when all the connections have been
established.
--]]
function ConnectionStream:createConnections(addresses, callback)
  local iter = function(address, callback)
    local split, client, options, ip
    split = misc.splitAddress(address)
    dns.lookup(split[1], function(err, ip)
      if (err) then
        callback(err)
        return
      end
      options = misc.merge({
        ip = ip,
        host = split[1],
        port = split[2],
        datacenter = address
      }, self._options)
      self:createConnection(options, callback)
    end)
  end

  async.series({
    function(callback)
      self._stateFile = path.join(self._options.stateDirectory, 'scheduler.state')
      self._scheduler = Scheduler:new(self._stateFile, {}, callback)
      self._scheduler:on('check', function(check, checkResult)
        self:_sendMetrics(check, checkResult)
      end)
    end,
    function(callback)
      self._scheduler:start()
      callback()
    end,
    -- connect
    function(callback)
      async.forEach(addresses, iter, callback)
    end
  }, callback)
end

function ConnectionStream:_sendMetrics(check, checkResults)
  local client = self:getClient()
  if client then
    client.protocol:request('check_metrics.post', check, checkResults)
  end
end

function ConnectionStream:_setDelay(datacenter)
  local maxDelay = consts.DATACENTER_MAX_DELAY
  local jitter = consts.DATACENTER_MAX_DELAY_JITTER
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

  logging.infof('%s %s:%d -> Retrying connection in %dms', datacenter, options.host, options.port, delay)
  timer.setTimeout(delay, function()
    self:emit('reconnect', options)
    self:createConnection(options, callback)
  end)
end

--[[
Restart a client that has failed on error, timeout, or end

client - client that needs restarting
options - passed to ConnectionStream:reconnect
callback - Callback called with (err)
]]--
function ConnectionStream:restart(client, options, callback)
  if client:isDestroyed() then
    return
  end

  client:destroy()

  -- Find a new client to handle time sync
  if self._activeTimeSyncClient == client then
    self._attachTimeSyncEvent(self:getClient())
  end

  -- The error we hit was rateLimit related.
  -- Shut down the agent.
  if client.rateLimitReached then
    client:log(logging.ERROR, fmt('Rate limit reached on connection to %s. ' ..
        'Shutting down this agent', client:getDatacenter()))

    self:shutdown('Shutting down. The rate limit was exceeded for the ' ..
     'agent API endpoint. Contact support if you need an increased rate limit.')
     return
  end

  self:reconnect(options, callback)
end

function ConnectionStream:shutdown(msg)
  for k, v in pairs(self._clients) do
    v:destroy()
  end

  -- Sleep to keep from busy restarting on upstart/systemd/etc
  timer.setTimeout(consts.RATE_LIMIT_SLEEP, function()
    logging.error(msg)
    process.exit(consts.RATE_LIMIT_RETURN_CODE)
  end)
end

function ConnectionStream:getClient()
  local client
  local latency
  local min_latency = 2147483647
  for k, v in pairs(self._clients) do
    latency = self._clients[k]:getLatency()
    if latency == nil then
      client = self._clients[k]
    elseif min_latency > latency then
      client = self._clients[k]
      min_latency = latency
    end
  end
  return client
end

--[[
The algorithm for syncing time follows:

Note: Promoted clients have been handshake accepted to the endpoint.

1. On promotion, attach a time_sync event to the client
2. If a client disconnects and it is the time sync client then find
   a new client to perform time syncs
]]--
function ConnectionStream:_attachTimeSyncEvent(client)
  if not client then
    self._activeTimeSyncClient = nil
    return
  end
  if self._activeTimeSyncClient then
    -- client already attached
    return
  end
  self._activeTimeSyncClient = client
  client:on('time_sync', function(timeObj)
    vtime.timesync(timeObj.agent_send_timestamp, timeObj.server_receive_timestamp,
                   timeObj.server_response_timestamp, timeObj.agent_recv_timestamp)
  end)
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
  self:_attachTimeSyncEvent(client)
  self:emit('promote')
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
    guid = self._guid,
    timeout = consts.CONNECT_TIMEOUT
  }, options)

  local client = AgentClient:new(opts, self._scheduler)
  client:on('error', function(errorMessage)
    local err = {}
    err.ip = opts.ip
    err.port = opts.port
    err.host = opts.host
    err.datacenter = opts.datacenter
    err.message = errorMessage

    self:restart(client, opts, callback)

    if err then
      self:emit('error', err)
    end
  end)

  client:on('timeout', function()
    client:log(logging.DEBUG, 'Client Timeout')
    self:restart(client, opts, callback)
  end)

  client:on('end', function()
    self:emit('client_end', client)
    client:log(logging.DEBUG, 'Remote endpoint closed the connection')
    self:restart(client, opts, callback)
  end)

  client:on('handshake_success', function(data)
    self:_promoteClient(client)
    self._delays[options.datacenter] = 0
    client:startHeartbeatInterval()
    self:emit('handshake_success')
    self._messages:emit('handshake_success', client, data)
  end)

  client:on('message', function(msg)
    self._messages:emit('message', client, msg)
  end)

  client:connect()
  client.datacenter = opts.datacenter
  self._unauthedClients[opts.datacenter] = client

  client:on('connect', function()
    self:emit('connect', client)
  end)

  callback()

  return client
end

local exports = {}
exports.ConnectionStream = ConnectionStream
return exports
