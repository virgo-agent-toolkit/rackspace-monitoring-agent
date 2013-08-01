local Scheduler = require('/schedule').Scheduler
local ConnectionStream = require("base/client/connection_stream").ConnectionStream

local VirgoConnectionStream = ConnectionStream:extend()
function VirgoConnectionStream:initialize(id, token, guid, upgradeEnabled, options, types)
  ConnectionStream.initialize(self, id, token, guid, upgradeEnabled, options, types)
  self._scheduler = Scheduler:new()
  self._scheduler:on('check.completed', function(check, checkResult)
    self:_sendMetrics(check, checkResult)
  end)
end

function VirgoConnectionStream:_createConnection(options)
  local client = ConnectionStream._createConnection(self, options)
  client:setScheduler(self._scheduler)
  return client
end

function VirgoConnectionStream:_sendMetrics(check, checkResult)
  local client = self:getClient()
  if client then
    client.protocol:request('check_metrics.post', check, checkResult)
  end
end

return VirgoConnectionStream
