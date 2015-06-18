local Scheduler = require('../schedule').Scheduler

local ConnectionStream = require("virgo/client/connection_stream").ConnectionStream
local loggingUtil = require('virgo/util/logging')
local logging = require('logging')
local fmt = require('string').format

local VirgoConnectionStream = ConnectionStream:extend()
function VirgoConnectionStream:initialize(id, token, guid, upgradeEnabled, options, features, types, codeCert)
  ConnectionStream.initialize(self, id, token, guid, upgradeEnabled, options, features, types, codeCert)
  self._log = loggingUtil.makeLogger('agent')
  self._scheduler = Scheduler:new()
  self._scheduler:on('check.completed', function(check, checkResult)
    -- Add the minimum check period
    checkResult:setMinimumCheckPeriod(self._scheduler:getMinimumCheckPeriod())
    -- Send the metrics
    self:_sendMetrics(check, checkResult)
  end)
  self._scheduler:on('check.deleted', function(check)
    self._log(logging.INFO, fmt('Deleted Check (id=%s, iid=%s)', 
      check.id, check:getInternalId()))
  end)
  self._scheduler:on('check.created', function(check)
    self._log(logging.INFO, fmt('Created Check (id=%s, iid=%s)', 
      check.id, check:getInternalId()))
  end)
  self._scheduler:on('check.modified', function(check)
    self._log(logging.INFO, fmt('Modified Check (id=%s, iid=%s)', 
      check.id, check:getInternalId()))
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
