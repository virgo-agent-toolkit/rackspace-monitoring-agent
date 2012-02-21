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

local JSON = require('json')
local utils = require('utils')
local Object = require('core').Object

local Response = Object:extend()
function Response:initialize()
  self.v = 1
  self.id = 1
  self.source = 'endpoint'
  self.target = 'X'
  self.result = nil
end

local AgentProtocol = Object:extend()
function AgentProtocol:initialize(hello, client)
  self.v = 1
  self.id = 1
  self.source = self._id
  self.target = self._target
  self.result = nil
  self._conn = client
  self._target = hello.source
  self._id = hello.target
  self._methods = {}
  self._methods["handshake.hello"] = utils.bind(AgentProtocol.handshakeHello, self)
end

function AgentProtocol:handshakeHello(request)
  local response = Response:new()
  self._conn:write(JSON.stringify(response))
end

function AgentProtocol:request(request)
  self._methods[request.method](request)
end

local exports = {}
exports.Response = Response
exports.AgentProtocol = AgentProtocol
return exports
