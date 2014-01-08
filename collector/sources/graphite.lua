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
local SourceBase = require('../base').SourceBase

local JSON = require('json')
local logging = require('logging')
local net = require('net')
local table = require('table')
local utils = require('utils')

local fmt = require('string').format
local merge = require('/util/misc').merge
local split = require('/util/misc').split

local LineEmitter = require('line-emitter').LineEmitter
local CheckResult = require('/check/base').CheckResult

-------------------------------------------------------------------------------

local GraphiteSource = SourceBase:extend()
function GraphiteSource:initialize(stream, options)
  SourceBase.initialize(self, 'graphite', stream, options)

  self._log(logging.INFO, 'Graphite Source')

  self.options = merge({
    host = options['monitoring_collectors_graphite_host'],
    port = options['monitoring_collectors_graphite_port']
  }, options)

  self:_init()
end

function GraphiteSource:_init()
  if self._server then
    return
  end
  self._server = net.createServer(utils.bind(GraphiteSource._onClient, self))
  self._server:listen(tonumber(self.options.port), self.options.host)
  self._log(logging.INFO, fmt('Listening on: %s:%s', self.options.host, self.options.port))
end

function GraphiteSource:_onClient(client)
  client.metrics = {}
  client.le = LineEmitter:new()
  client.le:on('data', function(line)
    table.insert(client.metrics, line)
  end)
  client:on('data', function(data)
    client.le:write(data)    
  end)
  client:on('end', function()
    self:emit('metrics', client.metrics, self)
  end)
end

function GraphiteSource:resume()
  self:_init()
end

function GraphiteSource:pause()
  self._server:close(function()
    self._server = nil
  end)
end

function GraphiteSource:translateMetrics(metrics, callback)
  local PREFIX = fmt('rackspace.monitoring.%s', self.name)
  local cr = CheckResult:new()

  for _, metric in pairs(metrics) do
    local values = split(metric)
    if #values == 3 then
      local key = fmt('%s.%s', PREFIX, values[1])
      cr:addMetric(key, nil, 'double', values[2])
      cr:setTimestamp(values[3])
    end
  end

  callback(nil, cr)
end

-------------------------------------------------------------------------------

local exports = {}
exports.Source = GraphiteSource
return exports
