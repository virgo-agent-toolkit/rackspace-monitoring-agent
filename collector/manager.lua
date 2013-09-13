local Emitter = require('core').Emitter

local logging = require('logging')
local loggingUtil = require('../util/logging')

local fmt = require('string').format
local table = require('table')
local timer = require('timer')
local utils = require('utils')
local vutils = require('virgo_utils')

local Metrics = require('./base').Metrics

local DEFAULT_INTERVAL = 1000

-------------------------------------------------------------------------------

local Manager = Emitter:extend()
function Manager:initialize(options)
  self.collectors = {}
  self.metrics = {}

  self.options = options or {}
  self.options.interval = self.options.interval or DEFAULT_INTERVAL

  self._log = loggingUtil.makeLogger('collector')

  self:_startIntervalTimer()
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
  self._log(logging.DEBUG, fmt('(metrics_count=%i)', #self.metrics))
  for _, v in ipairs(self.metrics) do
    self._log(logging.DEBUG, tostring(v))
  end
  self.metrics = {}
end

function Manager:_addMetrics(metrics, collector)
  table.insert(self.metrics,
               Metrics:new(collector, vutils.gmtNow(), metrics))
end

function Manager:addCollector(collector)
  self._log(logging.DEBUG, fmt('Adding Collector %s', collector:getName()))
  table.insert(self.collectors, collector)
  collector:on('metrics', utils.bind(Manager._addMetrics, self))
end

function Manager:pause()
  self._log(logging.DEBUG, 'paused')
  self:_stopIntervalTimer()
end

function Manager:resume()
  self._log(logging.DEBUG, 'resumed')
  self:_startIntervalTimer()
end

-------------------------------------------------------------------------------

local exports = {}
exports.Manager = Manager
return exports
