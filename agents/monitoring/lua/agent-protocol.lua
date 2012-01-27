local JSON = require('json')
local Object = require('object')
local utils = require('utils')

local Response = Object:extend()
function Response.prototype:initialize()
  self.v = 1
  self.id = 1
  self.source = self._id
  self.target = self._target
  self.result = nil
end

local AgentProtocol = Object:extend()

function AgentProtocol.prototype:initialize(hello, client)
  self.v = 1
  self.id = 1
  self.source = self._id
  self.target = self._target
  self.result = nil
  self._conn = client
  self._target = hello.source
  self._id = hello.target
  self._methods = {}
  self._methods["handshake.hello"] = utils.bind(AgentProtocol.prototype.handshake_hello, self)
end

function AgentProtocol.prototype:handshake_hello(request)
  local response = Response:new()
  self._conn:write(JSON.stringify(response))
end

function AgentProtocol.prototype:request(request)
  self._methods[request.method](request)
end

return AgentProtocol
