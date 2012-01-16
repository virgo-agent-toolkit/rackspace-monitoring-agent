local JSON = require('json')
local utils = require('utils')

local AgentProtocol = {}
AgentProtocol.prototype = {}

function AgentProtocol.prototype:new_response(request)
  local response = {}
  response.v = 1
  response.id = request.id
  response.source = self._id
  response.target = self._target
  response.result = nil
  return response
end

function AgentProtocol.prototype:handshake_hello(request)
  local response = self:new_response(request)
  self._conn:write(JSON.stringify(response) .. '\n')
end

function AgentProtocol.prototype:request(request)
  self._methods[request.method](request)
end

function AgentProtocol.new(hello, client)
  assert(hello ~= nil)
  assert(client ~= nil)

  local ap = {}
  ap._conn = client
  ap._target = hello.source
  ap._id = hello.target

  ap._methods = {}
  ap._methods["handshake.hello"] = utils.bind(ap, AgentProtocol.prototype.handshake_hello)
  setmetatable(ap, {__index=AgentProtocol.prototype})
  return ap
end

return AgentProtocol
