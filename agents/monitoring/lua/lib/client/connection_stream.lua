local Object = require('core').Object
local AgentClient = require('./client').AgentClient
local logging = require('logging')

local CONNECT_TIMEOUT = 6000

local ConnectionStream = Object:extend()
function ConnectionStream:initialize(id, token)
  self._id = id
  self._token = token
  self._clients = {}
end

function ConnectionStream:createConnection(datacenter, host, port, callback)
  local client = AgentClient:new(self._id, self._token, host, port, CONNECT_TIMEOUT)
  client:connect(function(err)
    if err then
      callback(err)
      return
    end
    client.datacenter = datacenter
    self._clients[datacenter] = client
    callback();
  end)
  client:on('error', function(err)
    logging.log(logging.ERR, err.message)
    client:close()
    callback(err)
  end)
end

local exports = {}
exports.ConnectionStream = ConnectionStream
return exports
