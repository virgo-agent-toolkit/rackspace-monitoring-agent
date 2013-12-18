--[[
Copyright 2013 Rackspace

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]
local Scheduler = require('/schedule').Scheduler
local ConnectionStream = require("./connection_stream").ConnectionStream

local fmt = require('string').format

local logging = require('logging')
local loggingUtil = require('/util/logging')
local misc = require('/util/misc')

local collector = require('/collector')

local DEFAULT_COLLECTOR_SINKS = 'rackspace_monitoring'

local VirgoConnectionStream = ConnectionStream:extend()
function VirgoConnectionStream:initialize(id, token, guid, upgradeEnabled, options, types)
  ConnectionStream.initialize(self, id, token, guid, upgradeEnabled, options, types)
  self._options = misc.merge(options, virgo.config)
  self._log = loggingUtil.makeLogger('Stream.virgo')
  self._collector_manager = collector.manager.Manager:new(self._options)
  self:_createCollectors()
  self._scheduler = Scheduler:new()
  self._scheduler:on('check.completed', function(check, checkResult)
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
  self._log(logging.DEBUG, fmt('creating connection (ip=%s, port=%s)', options.host, options.port))
  local client = ConnectionStream._createConnection(self, options)
  client:setScheduler(self._scheduler)
  return client
end

function VirgoConnectionStream:_createCollectors()
  -- parse collectors
  local collectors_enabled = virgo.config['collectors_enabled']
  if not collectors_enabled then
    return
  end

  -- parse sinks
  local collectors_sinks = virgo.config['collectors_sinks']
  if not collectors_sinks then
    collectors_sinks = DEFAULT_COLLECTOR_SINKS
  end

  self._log(logging.INFO, fmt('collectors enabled: %s', collectors_enabled))
  self._log(logging.INFO, fmt('sinks enabled: %s', collectors_sinks))

  -- Create sinks
  local sinks = misc.split(collectors_sinks, "[^,%s]+")
  for _, name in pairs(sinks) do
    local sink = collector.createSink(self, name, self._options)
    self._collector_manager:addSink(sink)
  end

  -- Create sources
  local collectors = misc.split(collectors_enabled, "[^,%s]+")
  for _, name in pairs(collectors) do
    local source = collector.createSource(self, name, self._options)
    if source then
      self._collector_manager:addSource(source)
    else
      self._log(logging.ERROR, fmt('%s source not found', name))
    end
  end

  self._collector_manager:resume()
end

function VirgoConnectionStream:_sendMetrics(check, checkResult)
  local client = self:getClient()
  if client then
    self._log(logging.DEBUG, fmt('sending metrics for check %s', check.id))
    client.protocol:request('check_metrics.post', check, checkResult)
  end
end

function VirgoConnectionStream:_sendRawMetrics(rawMetrics)
  local client = self:getClient()
  if client then
    for _, v in pairs(rawMetrics) do
      self._log(logging.DEBUG, fmt('sending raw metrics: %s', tostring(v)))
    end
    -- TODO Uncomment this line for pushing of raw metrics
    -- client.protocol:request('metrics.post', rawMetrics)
  end
end

return VirgoConnectionStream
