local JSON = require('json')
local Emitter = require('emitter')
local utils = require('utils')
local logging = require('logging')

local AgentProtocol = require('./agent-protocol')

local AgentProtocolConnection = {}
utils.inherits(AgentProtocolConnection, Emitter)

function AgentProtocolConnection.prototype:request(incoming)
  logging.log(logging.DBG, 'connection:request: ' .. incoming)

  local request = JSON.parse(incoming)
  local source = request.source

  if request.method == "handshake.hello" and self._endpoints[source] == nil then
    self._endpoints[source] = AgentProtocol.new(request, self._conn)
  end

  -- TODO: filter functions out
  ep = self._endpoints[source]
  return ep:request(request)
end

function AgentProtocolConnection.prototype:_onData(data)
  local client = self._conn
  newline = data:find("\n")
  if newline then
    -- TODO: use a better buffer
    self._buf = self._buf .. data:sub(1, newline - 1)
    self:request(self._buf)
    self._buf = data:sub(newline)
  else
    self._buf = self._buf .. data
  end
end

function AgentProtocolConnection.new(myid, conn)
  assert(conn ~= nil)
  assert(myid ~= nil)

  local s = AgentProtocolConnection.new_obj()
  s._myid = myid
  s._conn = conn
  s._conn:on('data', utils.bind(s, AgentProtocolConnection.prototype._onData))
  s._buf = ""
  s._endpoints = { }
  return s
end

return AgentProtocolConnection
