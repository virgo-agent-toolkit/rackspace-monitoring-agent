local net = require('net')
local AgentProtocolConnection = require('./agent-protocol-connection')

local AgentProtocolServer = {}

function AgentProtocolServer.sample()
  local server = net.createServer(function (client)
    local ap = AgentProtocolConnection.new('sample', client)
  end)
  server:listen(8081, "127.0.0.1", function(err)
    print("AgentProtocol listening at 127.0.0.1:8081")
  end)
end

function AgentProtocolServer.run()
  AgentProtocolServer.sample()
end

return AgentProtocolServer
