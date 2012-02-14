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
