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
local Object = require('core').Object
local dgram = require('dgram')
local timer = require('timer')
local table = require('table')
local math = require('math')
local utils = require('utils')
local hrtime = require('uv').Process.hrtime
local misc = require('./misc')

----------------------------

local PREFIX_STATS = 'statsd.'
local DEFAULT_PORT = 8125
local DEFAULT_INTERVAL = 10000
local DEFAULT_THRESHOLD = 90

local packets_received = PREFIX_STATS .. 'packets_received'
local bad_lines_seen = PREFIX_STATS .. 'bad_lines_seen'

----------------------------

local Set = Object:extend()
function Set:initialize()
  self.store = {}
end

function Set:insert(value)
  if value then
    self.store[value] = value
  end
end

function Set:clear()
  self.store = {}
end

function Set:has(value)
  return self.store[value] ~= nil
end

function Set:values()
  local t = {}
  for k, _ in pairs(self.store) do
    table.insert(t, k)
  end
  return t
end

----------------------------

local Statsd = Emitter:extend()
function Statsd:initialize(options)
  self._options = options or {}
  self._counters = {}
  self._counters[packets_received] = 0
  self._counters[bad_lines_seen] = 0
  self._timers = {}
  self._timer_counters = {}
  self._gauges = {}
  self._sets = {}
  self._sock = dgram.createSocket('udp4')
  self._sock:on('message', utils.bind(Statsd._onMessage, self))

  self._bound = false

  if not self._options.port then
    self._options.port = DEFAULT_PORT
  end
  if not self._options.metrics_interval then
    self._options.metrics_interval = DEFAULT_INTERVAL
  end
  if not self._options.percent_threshold then
    self._options.percent_threshold = { DEFAULT_THRESHOLD }
  end
end

function Statsd:bind(port)
  if self._bound then
    return
  end
  self._bound = true
  self._sock:bind(self._options.port)
end

function Statsd:close()
  self._sock:close()
  if self._interval then
    timer.clearTimer(self._interval)
  end
end

function Statsd:_processMetrics(metrics, callback)
  local start_time = hrtime()
  local counter_rates = {}
  local timer_data = {}
  local statsd_metrics = {}

  if not metrics.pctThreshold then
    metrics.pctThreshold = self._options.percent_threshold
  end

  for k, v in pairs(metrics.counters) do
    counter_rates[k] = v / (self._options.metrics_interval / 1000)
  end

  for k, v in pairs(metrics.timers) do
    local current_timer_data = {}
    timer_data[k] = {}

    if #v == 0 then
      break
    end

    table.sort(v)
    local count = #v
    local min = v[1]
    local max = v[count]

    local cumulativeValues = { min }

    if count ~= 1 then
      for i=2, count do
        table.insert(cumulativeValues, v[i] + cumulativeValues[i - 1])
      end
    end

    local sum = min
    local mean = min
    local thresholdBoundary = max

    for _, pct in pairs(metrics.pctThreshold) do
      if count > 1 then
        local numInThreshold = misc.round(math.abs(pct) / 100 * count)
        if numInThreshold ~= 0 then
          if pct > 0 then
            thresholdBoundary = v[numInThreshold]
            sum = cumulativeValues[numInThreshold]
          else
            thresholdBoundary = v[count - numInThreshold + 1]
            sum = cumulativeValues[count] - cumulativeValues[count - numInThreshold]
          end
        end
        mean = sum / numInThreshold
      end

      local clean_pct = tostring(pct)
      clean_pct = clean_pct:gsub('\\.', '_'):gsub('-', 'top')
      current_timer_data['mean_' .. clean_pct] = mean
      if pct > 0 then
        current_timer_data['upper_' .. clean_pct] = thresholdBoundary
      else
        current_timer_data['lower_' .. clean_pct] = thresholdBoundary
      end
      current_timer_data['sum_' .. clean_pct] = sum
    end

    sum = cumulativeValues[count]
    mean = sum / count

    local sumOfDiffs = 0
    for i = 1, count do
      sumOfDiffs = sumOfDiffs + (v[i] - mean) * (v[i] - mean)
    end

    local mid = math.floor(count / 2) + 1
    local median
    if count % 2 == 0 then
      median = v[mid]
    else
      median = (v[mid] + v[mid]) / 2
    end

    local stddev = math.sqrt(sumOfDiffs / count)
    current_timer_data['std'] = stddev
    current_timer_data['upper'] = max
    current_timer_data['lower'] = min
    current_timer_data['count'] = metrics.timer_counters[k]
    current_timer_data['count_ps'] = metrics.timer_counters[k] / (self._options.metrics_interval / 1000)
    current_timer_data['sum'] = sum
    current_timer_data['mean'] = mean
    current_timer_data['median'] = median


    timer_data[k] = current_timer_data
  end

  statsd_metrics.processing_time = hrtime() - start_time

  metrics.counter_rates = counter_rates
  metrics.timer_data = timer_data
  metrics.statsd_metrics = statsd_metrics

  callback(metrics)
end

function Statsd:_onMessage(msg, rinfo)
  local metrics

  if msg:find('\n') then
    metrics = misc.split(msg, '\n')
  else
    metrics = { misc.trim(msg) }
  end

  self._counters[packets_received] = self._counters[packets_received] + 1

  for _, metric in ipairs(metrics) do
    local metric_name, metric_value, metric_type, bits, fields
    local sampleRate = 1

    bits = misc.split(metric, ':')
    fields = misc.split(bits[2], '|')

    metric_name = bits[1]
    metric_value = tonumber(fields[1])
    metric_value_raw = fields[1]
    metric_type = fields[2]

    if fields[3] then
      sampleRate = tonumber(fields[3]:sub(2))
    end

    if metric_type == 'c' then
      -- counter
      if not self._counters[metric_name] then
        self._counters[metric_name] = 0
      end
      self._counters[metric_name] = self._counters[metric_name] + (metric_value * (1 / sampleRate))
    elseif metric_type == 'ms' then
      -- timers
      if not self._timers[metric_name] then
        self._timers[metric_name] = {}
        self._timer_counters[metric_name] = 0
      end
      table.insert(self._timers[metric_name], metric_value or 0)
      self._timer_counters[metric_name] = self._timer_counters[metric_name] + (1/sampleRate)
    elseif metric_type == 'g' then
      -- gauges
      if metric_value_raw:sub(1, 1) == '+' or
         metric_value_raw:sub(1, 1) == '-' then
        self._gauges[metric_name] = self._gauges[metric_name] + metric_value
      else
        self._gauges[metric_name] = metric_value
      end
    elseif metric_type == 's' then
      -- sets
      local set = self._sets[metric_name]
      if not set then
        set = Set:new()
        self._sets[metric_name] = set
      end
      if metric_value_raw == '' then
        set:insert('0')
      else
        set:insert(metric_value_raw)
      end
    end
  end
end

function Statsd:_onInterval()
  local metrics_hash = {}

  metrics_hash.timer_counters = self._timer_counters
  metrics_hash.counters = self._counters
  metrics_hash.timers = self._timers
  metrics_hash.gauges = self._gauges
  metrics_hash.percent_threshold = self._options.percent_threshold

  -- copy sets
  metrics_hash.sets = {}
  for k, v in pairs(self._sets) do
    metrics_hash.sets[k] = v:values()
  end

  self:_processMetrics(metrics_hash, function(metrics)
    self:emit('metrics', metrics)

    for k, _ in pairs(self._counters) do
      self._counters[k] = 0
    end
    for k, _ in pairs(self._timers) do
      self._timers[k] = {}
    end
    for k, _ in pairs(self._timer_counters) do
      self._timer_counters[k] = 0
    end
    for k, _ in pairs(self._sets) do
      self._sets[k]:clear()
    end
  end)
end

function Statsd:run()
  if self._interval then
    return
  end
  self._interval = timer.setInterval(self._options.metrics_interval, utils.bind(Statsd._onInterval, self))
end

function version()
  return '0.1.0-dev'
end

local exports = {}
exports.Statsd = Statsd
exports.version = version
return exports
