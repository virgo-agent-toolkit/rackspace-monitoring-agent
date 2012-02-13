local net = require('net')
local timer = require('timer')
local Error = require('core').Error
local Object = require('core').Object
local Emitter = require('core').Emitter
local logging = require('logging')
local AgentProtocolConnection = require('../protocol/connection')

local fmt = require('string').format

local AgentClient = Emitter:extend()

function AgentClient:initialize(id, token, host, port, timeout)
  self.protocol = nil
  self._id = id
  self._token = token
  self._target = 'endpoint'
  self._sock = nil
  self._host = host
  self._port = port
  self._timeout = timeout or 5000
end

function AgentClient:connect()
  -- Create connection timeout
  connectTimeout = timer.setTimeout(self._timeout, function()
    self:emit('error', Error:new(fmt('Connect timeout to %s:%s', self._host, self._port)))
  end)

  logging.log(logging.INFO, fmt("Connecting to %s:%s", self._host, self._port))
  self._sock = net.createConnection(self._port, self._host, function()
    -- stop the timeout timer since there is a connect
    timer.clearTimer(connectTimeout);
    logging.log(logging.INFO, fmt("Connected to %s:%s", self._host, self._port))

    -- setup protocol and begin handshake
    self.protocol = AgentProtocolConnection:new(self._id, self._token, self._sock)
    self.protocol:startHandshake()
  end)
  self._sock:on('error', function(err)
    timer.clearTimer(connectTimeout);
    self:emit('error', err)
  end)
end

function AgentClient:close()
  self._sock:close()
end

local exports = {}
exports.AgentClient = AgentClient
return exports
