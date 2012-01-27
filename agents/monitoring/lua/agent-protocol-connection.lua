local JSON = require('json')
local Emitter = require('emitter')
local utils = require('utils')

local AgentProtocol = require('./agent-protocol')

local AgentProtocolConnection = Emitter:extend()

function AgentProtocolConnection.prototype:request(incoming)
  local request = JSON.parse(incoming)
  local source = request.source

  if request.method == "handshake.hello" and self._endpoints[source] == nil then
    p(self._conn)
    self._endpoints[source] = AgentProtocol.new(request, self._conn)
  end

  print("Got request")
  p(request)
  -- TODO: filter functions out
  ep = self._endpoints[source]
  return ep:request(request)
end

function AgentProtocolConnection.prototype:_onData(data)
  local client = self._conn
  newline = data:find("\n")
  if newline then
    -- TODO: use a better buffer
    self._buf = self._buf .. data:sub(1, newline)
    self:request(self._buf)
    self._buf = data:sub(newline)
  else
    self._buf = self._buf .. data
  end
end

function AgentProtocolConnection:initialize(myid, conn)
  assert(conn ~= nil)
  assert(myid ~= nil)
  self._myid = myid
  self._conn = conn
  self._conn:on('data', utils.bind(AgentProtocolConnection.prototype._onData, self))
  self._buf = ""
  self._endpoints = { }
end

return AgentProtocolConnection
