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

local ConnectionMessages = require('./connection_messages').ConnectionMessages
local UpgradePollEmitter = require('./upgrade').UpgradePollEmitter

local Scheduler = require('../schedule').Scheduler
local AgentClient = require('./client').AgentClient
local logging = require('logging')
local consts = require('../util/constants')
local misc = require('../util/misc')
local vtime = require('virgo-time')
local path = require('path')
local utils = require('utils')
local version = require('../util/version')

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
  self._scheduler = Scheduler:new()
  self._scheduler:on('check.completed', function(check, checkResult)
    self:_sendMetrics(check, checkResult)
  end)

  self._upgrade = UpgradePollEmitter:new()
  self._upgrade:on('upgrade', utils.bind(ConnectionStream._onUpgrade, self))
end

function ConnectionStream:getUpgrade()
  return self._upgrade
end

function ConnectionStream:_onUpgrade()
  local client = self:getClient()
  local bundleVersion = version.bundle
  local processVersion = version.process

  if not client then
    return
  end

  function updateGenerator(client, name, version, callback)
    client.protocol:request(name, function(err, msg)
        if err then
          logging.errorf(name .. ' failed: %s', err.message)
          callback(err)
          return
        end
        if misc.compareVersions(msg.result.version, version) > 0 then
          self._messages:getUpgrade(name, client);
          callback(nil, msg.result.version)
        else
          callback()
        end
    end)
  end

  async.parallel({
    function(callback)
      updateGenerator(client, 'binary_upgrade.get_version', processVersion, function(err, version)
        if err then
          callback(err)
          return
        end

        if version then
          logging.infof('Found binary upgrade to version %s', version)
        end

        callback()
      end)
    end,
    function(callback)
      updateGenerator(client, 'bundle_upgrade.get_version', bundleVersion, function(err, version)
        if err then
          callback(err)
          return
        end

        if version then
          logging.infof('Found bundle upgrade to version %s', version)
        end

        callback()
      end)
    end
  })
end

--[[
Create and establish a connection to the multiple endpoints.

addresses - An Array of ip:port pairs
callback - Callback called with (err) when all the connections have been
established.
--]]
function ConnectionStream:createConnections(endpoints, callback)
  local iter = function(endpoint, callback)
    dns.lookup(endpoint.host, function(err, ip)
      if (err) then
        callback(err)
        return
      end
      local options = misc.merge({
        host = endpoint.host,
        port = endpoint.port,
        ip = ip,
        id = self._id,
        datacenter = tostring(endpoint),
        token = self._token,
        guid = self._guid,
        timeout = consts.CONNECT_TIMEOUT
      }, self._options)

      self:createConnection(options)
      callback()
    end)
  end

  async.series({
    -- connect
    function(callback)
      async.forEach(endpoints, iter, callback)
    end
  }, callback)
end

function ConnectionStream:clearDelay(datacenter)
  if self._delays[datacenter] then
    self._delays[datacenter] = nil
  end
end

--[[
Create and establish a connection to the endpoint.

datacenter - Datacenter name / host alias.
host - Hostname.
port - Port.
callback - Callback called with (err)
]]--
function ConnectionStream:_createConnection(options)
  local client = AgentClient:new(options, self._scheduler, self)
  client:on('error', function(errorMessage)
    local err = {}
    err.ip = options.ip
    err.host = options.host
    err.port = options.port
    err.datacenter = options.datacenter
    err.message = errorMessage

    client:destroy()
  end)

  client:on('respawn', function()
    client:log(logging.DEBUG, 'Respawning client')
    self:_restart(client, options)
  end)

  client:on('timeout', function()
    client:log(logging.DEBUG, 'Client Timeout')
    client:destroy()
  end)

  client:on('connect', function()
    client:getMachine():react(client, 'connect')
  end)

  client:on('end', function()
    self:emit('client_end', client)
    client:log(logging.DEBUG, 'Remote endpoint closed the connection')
    client:destroy()
  end)

  client:on('handshake_success', function(data)
    self:emit('handshake_success')
    client:getMachine():react(client, 'handshake_success')
    self._messages:emit('handshake_success', client, data)
  end)

  client:on('message', function(msg)
    self._messages:emit('message', client, msg)
    client:getMachine():react(client, 'message', msg)
  end)

  client:setDatacenter(options.datacenter)
  self._unauthedClients[client:getDatacenter()] = client

  return client
end

function ConnectionStream:_sendMetrics(check, checkResults)
  local client = self:getClient()
  if client then
    client.protocol:request('check_metrics.post', check, checkResults)
  end
end

function ConnectionStream:_setDelay(datacenter)
  local previousDelay = self._delays[datacenter]

  if previousDelay == nil then
    previousDelay = misc.calcJitter(consts.DATACENTER_FIRST_RECONNECT_DELAY,
                                    consts.DATACENTER_FIRST_RECONNECT_DELAY_JITTER)
  end

  local delay = math.min(previousDelay, consts.DATACENTER_RECONNECT_DELAY)
  delay = misc.calcJitter(delay, consts.DATACENTER_RECONNECT_DELAY_JITTER)
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
function ConnectionStream:reconnect(options)
  local datacenter = options.datacenter
  local delay = self:_setDelay(datacenter)

  logging.infof('%s %s:%d -> Retrying connection in %dms', 
                datacenter, options.host, options.port, delay)
  self:emit('reconnect', options)
  timer.setTimeout(delay, function()
    self:createConnection(options)
  end)
end

--[[
Restart a client that has failed on error, timeout, or end

client - client that needs restarting
options - passed to ConnectionStream:reconnect
callback - Callback called with (err)
]]--
function ConnectionStream:_restart(client, options, callback)
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

function ConnectionStream:isTimeSyncActive()
  return self._activeTimeSyncClient ~= nil
end

function ConnectionStream:getActiveTimeSyncClient()
  return self._activeTimeSyncClient
end

function ConnectionStream:setActiveTimeSyncClient(client)
  self._activeTimeSyncClient = client
  self:_attachTimeSyncEvent(client)
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
    return
  end
  client:on('time_sync', function(timeObj)
    vtime.timesync(timeObj.agent_send_timestamp, timeObj.server_receive_timestamp,
                   timeObj.server_response_timestamp, timeObj.agent_recv_timestamp)
  end)
end

--[[
Move an unauthenticated client to the list of clients that have been authenticated.
client - the client.
]]--
function ConnectionStream:promoteClient(client)
  local datacenter = client:getDatacenter()
  client:log(logging.INFO, fmt('Connection has been authenticated to %s', datacenter))
  self._clients[datacenter] = client
  self._unauthedClients[datacenter] = nil
  self:emit('promote')
end

--[[
Create and establish a connection to the endpoint.

datacenter - Datacenter name / host alias.
host - Hostname.
port - Port.
callback - Callback called with (err)
]]--
function ConnectionStream:createConnection(options)
  local opts = misc.merge({
    id = self._id,
    token = self._token,
    guid = self._guid,
    timeout = consts.CONNECT_TIMEOUT
  }, options)

  local client = self:_createConnection(options)
  client:connect()
  return client
end

local exports = {}
exports.ConnectionStream = ConnectionStream
return exports
