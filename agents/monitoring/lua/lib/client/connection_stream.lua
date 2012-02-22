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

local async = require('async')

local Emitter = require('core').Emitter
local AgentClient = require('./client').AgentClient
local logging = require('logging')
local misc = require('../util/misc')

local CONNECT_TIMEOUT = 6000

local ConnectionStream = Emitter:extend()
function ConnectionStream:initialize(id, token)
  self._id = id
  self._token = token
  self._clients = {}
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

function ConnectionStream:createConnection(datacenter, host, port, callback)
  local client = AgentClient:new(datacenter, self._id, self._token, host, port, CONNECT_TIMEOUT)
  client:on('error', function(err)
    err.host = host
    err.port = port
    err.datacenter = datacenter

    self:emit('error', err)
  end)
  client:connect(function(err)
    if err then
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
