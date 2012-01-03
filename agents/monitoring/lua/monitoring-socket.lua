local user_meta = require('utils').user_meta
local TCP = require('tcp')

local MonitoringSocket = {}
MonitoringSocket.prototype = {}
setmetatable(MonitoringSocket.prototype, TCP.meta)

function MonitoringSocket.new()
  local tcp = TCP.new()
  tcp.prototype = MonitoringSocket.prototype
  setmetatable(tcp, user_meta)
  return tcp
end

return MonitoringSocket
