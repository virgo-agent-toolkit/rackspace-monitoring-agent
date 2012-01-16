local net = require('net')
local logging = require('logging')
local AgentProtocolConnection = require('./agent-protocol-connection')

local AgentProtocolServer = {}

function AgentProtocolServer.create(port, host)
  host = host or '127.0.0.1'
  local server = net.createServer(function (client)
    local ap = AgentProtocolConnection.new('sample', client)
    client:on('end', function()
      client:close()
    end)
  end)
  server:listen(port, host, function(err)
    logging.log(logging.INFO, "AgentProtocol listening at " .. host .. ":" .. port)
  end)
  return server
end

return AgentProtocolServer
