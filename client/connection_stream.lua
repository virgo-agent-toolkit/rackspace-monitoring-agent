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

local AgentClient = require('./client').AgentClient
local logging = require('logging')
local consts = require('/base/util/constants')
local misc = require('/base/util/misc')
local vutils = require('virgo_utils')
local path = require('path')
local utils = require('utils')
local request = require('/base/protocol/request')

local ConnectionStream = Emitter:extend()
function ConnectionStream:initialize(id, token, guid, upgradeEnabled, options, types)
  self._id = id
  self._token = token
  self._guid = guid
  self._channel = nil
  self._clients = {}
  self._unauthedClients = {}
  self._delays = {}
  self._activeTimeSyncClient = nil
  self._upgradeEnabled = upgradeEnabled
  self._options = options or {}
  self._types = types or {}

  self._messages = ConnectionMessages:new(self)
  self._upgrade = UpgradePollEmitter:new()
  self._upgrade:on('upgrade', utils.bind(ConnectionStream._onUpgrade, self))
  self._upgrade:on('shutdown', function(reason)
    self:emit('shutdown', reason)
  end)
end

function ConnectionStream:getUpgrade()
  return self._upgrade
end

function ConnectionStream:setChannel(channel)
  self._channel = channel or consts.DEFAULT_CHANNEL
end

function ConnectionStream:_onUpgrade()
  local client = self:getClient()
  local bundleVersion = virgo.bundle_version
  local processVersion = virgo.virgo_version
  local uri_path, options

  if not self._upgradeEnabled then
    return
  end

  if not client then
    return
  end

  options = {
    method = 'GET',
    host = client._host,
    port = client._port,
    tls = client._tls_options
  }

  uri_path = fmt('/upgrades/%s/VERSION', self._channel)
  options = misc.merge({ path = uri_path, }, options)
  request.makeRequest(options, function(err, result, version)
    if err then
      client:log(logging.ERROR, 'Error on upgrade: ' .. tostring(err))
      return
    end
    version = misc.trim(version)
    client:log(logging.DEBUG, fmt('(upgrade) -> Current Version: %s', bundleVersion))
    client:log(logging.DEBUG, fmt('(upgrade) -> Upstream Version: %s', version))
    if version == '0.0.0-0' then
      client:log(logging.INFO, fmt('(upgrade) -> Upgrades Disabled'))
      return
    end
    if misc.compareVersions(version, bundleVersion) > 0 then
      client:log(logging.INFO, fmt('(upgrade) -> Performing upgrade to %s', version))
      self._messages:getUpgrade(version, client, function(err)
        if err then
          client:log(logging.ERROR, fmt('(upgrade) -> error: %s', tostring(err)))
          return
        end
        self._upgrade:onSuccess()
      end)
    end
  end)
end


function ConnectionStream:getChannel()
  return self._channel
end

--[[
Create and establish a connection to the multiple endpoints.

addresses - An Array of ip:port pairs
callback - Callback called with (err) when all the connections have been
established.
--]]
function ConnectionStream:createConnections(endpoints, callback)
  local iter = function(endpoint, callback)
    local baseOptions = misc.merge({}, self._options)
    local options = misc.merge(baseOptions, {
      endpoint = endpoint,
      id = self._id,
      datacenter = tostring(endpoint),
      token = self._token,
      guid = self._guid,
      timeout = consts.CONNECT_TIMEOUT
    })

    self:createConnection(options, callback)
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
  local clientType = self._types.AgentClient or AgentClient
  local client = clientType:new(options, self, self._types)
  client:on('error', function(errorMessage)
    local err = {}
    err.ip = options.ip
    err.host = options.host
    err.port = options.port
    err.datacenter = options.datacenter
    err.message = errorMessage
    client:log(logging.DEBUG, 'client error: %s', misc.toString(err))

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

options - datacenter, endpoint
  datacenter - Datacenter name / host alias.
  endpoint - Endpoint Structure containing SRV query or hostname/port.
callback - Callback called with (err)
]]--
function ConnectionStream:reconnect(options)
  local datacenter = options.datacenter
  local delay = self:_setDelay(datacenter)

  logging.infof('%s -> Retrying connection in %dms',
                datacenter, delay)
  self:emit('reconnect', options)
  timer.setTimeout(delay, function()
    self:createConnection(options, function(err)
      if err then
        logging.errorf('%s -> Error reconnecting (%s)',
          datacenter, tostring(err))
      end
    end)
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
    self:emit('shutdown', consts.SHUTDOWN_RATE_LIMIT)
    return
  end
  self:reconnect(options, callback)
end

function ConnectionStream:shutdown()
  self:done()
end

function ConnectionStream:done()
  for k, v in pairs(self._clients) do
    v:destroy()
  end
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
    vutils.timesync(timeObj.agent_send_timestamp, timeObj.server_receive_timestamp,
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
function ConnectionStream:createConnection(options, callback)
  local opts = misc.merge({
    id = self._id,
    token = self._token,
    guid = self._guid,
    timeout = consts.CONNECT_TIMEOUT
  }, options)

  options.endpoint:getHostInfo(function(err, host, ip, port)
    if err then
      logging.errorf('%s -> Error resolving (%s)',
        options.datacenter, tostring(err))
      self:reconnect(options, callback)
      return
    end

    opts.ip = ip
    opts.host = host
    opts.port = port

    local client = self:_createConnection(opts)
    client:connect()
    callback()
  end)
end

local exports = {}
exports.ConnectionStream = ConnectionStream
return exports
