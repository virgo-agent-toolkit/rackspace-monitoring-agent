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

local fmt = require('string').format

local JSON = require('json')

local logging = require('logging')
local loggingUtil = require('/util/logging')
local statsd = require('/lua_modules/statsd')
local utils = require('utils')

local CheckResult = require('/check/base').CheckResult

-------------------------------------------------------------------------------

local StatsdSource = SourceBase:extend()
function StatsdSource:initialize(stream, options)
  SourceBase.initialize(self, 'statsd', stream, options)

  self._log(logging.INFO, fmt('StatsD Source'))
  self._log(logging.INFO, fmt('Version: %s', statsd.version()))

  local function onMetrics(metrics)
    self:emit('metrics', metrics, self)
  end

  local statsd_options = {}
  statsd_options.host = options['monitoring_collectors_statsd_host']
  statsd_options.port = options['monitoring_collectors_statsd_port']

  self.statsd = statsd.Statsd:new(statsd_options)
  self.statsd:on('metrics', onMetrics)
  self.statsd:bind()

  self._log(logging.INFO, fmt('Listening on: %s:%s',
            self.statsd:getOptions().host,
            self.statsd:getOptions().port))

end

function StatsdSource:resume()
  self.statsd:run()
end

function StatsdSource:pause()
end

function StatsdSource:translateMetrics(metrics, callback)
  local cr = CheckResult:new()
  local client = self.stream:getClient()
  local entity_id = 'unknown'
  if client then
    entity_id = client:getEntityId()
  end
  local PREFIX = fmt('rackspace.monitoring.entities.%s.%s.', entity_id, self.name)
  if metrics.counter_rates then
    for k, v in pairs(metrics.counter_rates) do
      cr:addMetric(PREFIX .. 'counter_rates.' .. k, nil, 'double', v)
    end
  end
  if metrics.counters then
    for k, v in pairs(metrics.counters) do
      cr:addMetric(PREFIX .. 'counters.' .. k, nil, 'int64', JSON.stringify(v))
    end
  end
  if metrics.guages then
    for k, v in pairs(metrics.guages) do
      cr:addMetric(PREFIX .. 'guages.' .. k, nil, 'gauge', v)
    end
  end
  if metrics.timer_counters then
    for k, v in pairs(metrics.timer_counters) do
      cr:addMetric(PREFIX .. 'timer_counters.' .. k, nil, 'int64', v)
    end
  end
  if metrics.timer_data then
    for k, v in pairs(metrics.timer_data) do
      cr:addMetric(PREFIX .. 'timer_data.' .. k, nil, 'int64', v)
    end
  end
  if metrics.timers then
    for k, v in pairs(metrics.timers) do
      cr:addMetric(PREFIX .. 'timers.' .. k, nil, 'int64', v)
    end
  end
  if metrics.sets then
    for k, v in pairs(metrics.sets) do
      cr:addMetric(PREFIX .. 'sets.' .. k, nil, 'int64', JSON.stringify(v))
    end
  end
  callback(nil, cr)
end

-------------------------------------------------------------------------------

local exports = {}
exports.Source = StatsdSource
return exports
