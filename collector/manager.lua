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
local Emitter = require('core').Emitter

local logging = require('logging')
local loggingUtil = require('../util/logging')

local fmt = require('string').format
local table = require('table')
local timer = require('timer')
local utils = require('utils')
local vutils = require('virgo_utils')

local Metrics = require('./base').Metrics

local DEFAULT_INTERVAL = 10 * 1000
local MAX_LENGTH = 1022 * 1024 * 1024

-------------------------------------------------------------------------------

local Manager = Emitter:extend()
function Manager:initialize(options)
  self.sources = {}
  self.sinks = {}
  self.metrics = {}

  self.options = options or {}
  self.options.interval = self.options.interval or DEFAULT_INTERVAL

  self._log = loggingUtil.makeLogger('Collector.manager')
end

function Manager:_startIntervalTimer()
  if self.interval_timer == nil then
    self.interval_timer = timer.setInterval(self.options.interval,
                                            utils.bind(Manager._flush, self))
  end
end

function Manager:_stopIntervalTimer()
  if self.interval_timer then
    timer.clearTimer(self.interval_timer)
    self.interval_timer = nil
  end
end

function Manager:_flush()
  if #self.metrics == 0 then
    return
  end

  -- iterate backwards so we can remove the metrics safely
  local to_flush = {}
  local size = 0
  for i = table.getn(self.metrics), 1, -1 do
    local serialized_len = #self.metrics[i]:serialize()
    if serialized_len >= MAX_LENGTH then
      self._log(logging.DEBUG, fmt('Ignoring metric due to invalid size'))
      table.remove(self.metrics, i)
    else
      size = size + serialized_len
      if size < MAX_LENGTH then
        table.insert(to_flush, self.metrics[i])
        table.remove(self.metrics, i)
      end
    end
  end

  for i = 1, #self.sinks do
    self.sinks[i]:push(to_flush)
  end
end

function Manager:_addMetrics(metrics, source)
  self._log(logging.DEBUG, fmt('_addMetrics from %s', source:getName()))
  table.insert(self.metrics, Metrics:new(source, vutils.gmtNow(), metrics))
end

function Manager:addSource(source)
  self._log(logging.INFO, fmt('adding source %s', source:getName()))
  table.insert(self.sources, source)
  source:on('metrics', utils.bind(Manager._addMetrics, self))
  source:resume()
end

function Manager:addSink(sink)
  self._log(logging.INFO, fmt('adding sink %s', sink:getName()))
  table.insert(self.sinks, sink)
end

function Manager:pause()
  self._log(logging.INFO, 'paused')
  self:_stopIntervalTimer()
end

function Manager:resume()
  self._log(logging.INFO, 'resumed')
  self:_startIntervalTimer()
end

-------------------------------------------------------------------------------

local exports = {}
exports.Manager = Manager
return exports
