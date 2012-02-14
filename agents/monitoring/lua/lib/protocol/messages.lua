local Object = require('core').Object

--[[ Message ]]--

local Message = Object:extend()
function Message:initialize()
  self.id = '1'
  self.target = ''
  self.source = ''
end

--[[ Request ]]--

local Request = Message:extend()

function Request:initialize()
  Message.initialize(self)
  self.method = ''
  self.params = {}
end

function Request:serialize(msgId)
  self.id = msgId

  return {
    v = '1',
    id = self.id,
    target = self.target,
    source = self.source,
    method = self.method,
    params = self.params
  }
end

--[[ Handshake.Hello ]]--

local HandshakeHello = Request:extend()
function HandshakeHello:initialize(token, agentId)
  Request.initialize(self)
  self.method = 'handshake.hello'
  self.token = token
  self.agentId = agentId
end

function HandshakeHello:serialize(msgId)
  self.params.token = self.token
  self.params.agent_id = self.agentId
  return Request.serialize(self, msgId)
end

--[[ Exports ]]--

local exports = {}
exports.Request = Request
exports.Response = Response
exports.HandshakeHello = HandshakeHello
return exports
