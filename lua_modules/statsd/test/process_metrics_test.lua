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

local Statsd = require('../statsd').Statsd
local version = require('../statsd').version
local misc = require('../misc')

local function createMetrics()
  local counters = {};
  local gauges = {};
  local timers = {};
  local timer_counters = {};
  local sets = {};
  local pctThreshold = null;

  local metrics = {
    counters = counters,
    gauges = gauges,
    timers = timers,
    timer_counters = timer_counters,
    sets = sets,
    pctThreshold = pctThreshold
  }

  return metrics
end

local exports = {}

exports['test_counters_has_stats_count'] = function(test, asserts)
  local sd = Statsd:new()
  local metrics = createMetrics()
  metrics.counters['a'] = 2
  sd:_processMetrics(metrics, function(metrics)
    asserts.equal(metrics.counters['a'], 2)
    test.done()
  end)
end

exports['test_has_correct_rate'] = function(test, asserts)
  local sd = Statsd:new({metrics_interval = 100})
  local metrics = createMetrics()
  metrics.counters['a'] = 2
  sd:_processMetrics(metrics, function(metrics)
    asserts.equal(metrics.counter_rates['a'], 20)
    test.done()
  end)
end

exports['test_handle_empty'] = function(test, asserts)
  local sd = Statsd:new({metrics_interval = 100})
  local metrics = createMetrics()
  metrics.timers['a'] = {}
  metrics.timer_counters['a'] = 0
  sd:_processMetrics(metrics, function(metrics)
    asserts.equal(metrics.counter_rates['a'], nil)
    test.done()
  end)
end

exports['test_single_time'] = function(test, asserts)
  local sd = Statsd:new({metrics_interval = 100})
  local metrics = createMetrics()
  metrics.timers['a'] = {100}
  metrics.timer_counters['a'] = 1
  sd:_processMetrics(metrics, function(metrics)
    local timer_data = metrics.timer_data['a']
    asserts.equal(0, timer_data.std)
    asserts.equal(100, timer_data.upper)
    asserts.equal(100, timer_data.lower)
    asserts.equal(1, timer_data.count)
    asserts.equal(10, timer_data.count_ps)
    asserts.equal(100, timer_data.sum)
    asserts.equal(100, timer_data.median)
    asserts.equal(100, timer_data.mean)
    test.done()
  end)
end

exports['test_multiple_times'] = function(test, asserts)
  local sd = Statsd:new({metrics_interval = 100})
  local metrics = createMetrics()
  metrics.timers['a'] = {100, 200, 300}
  metrics.timer_counters['a'] = 3
  sd:_processMetrics(metrics, function(metrics)
    local timer_data = metrics.timer_data['a']
    asserts.equal(81.65, misc.round(timer_data.std, 2))
    asserts.equal(300, timer_data.upper)
    asserts.equal(100, timer_data.lower)
    asserts.equal(3, timer_data.count)
    asserts.equal(30, timer_data.count_ps)
    asserts.equal(600, timer_data.sum)
    asserts.equal(200, timer_data.mean)
    asserts.equal(200, timer_data.median)
    test.done()
  end)
end

exports['test_timers_single_time_single_percentile'] = function(test, asserts)
  local sd = Statsd:new({metrics_interval = 100})
  local metrics = createMetrics()
  metrics.timers['a'] = {100}
  metrics.timer_counters['a'] = 1
  metrics.pctThreshold = { 90 }
  sd:_processMetrics(metrics, function(metrics)
    local timer_data = metrics.timer_data['a']
    asserts.equal(100, timer_data.mean_90)
    asserts.equal(100, timer_data.upper_90)
    asserts.equal(100, timer_data.sum_90)
    test.done()
  end)
end

exports['test_timers_single_time_multiple_percentiles'] = function(test, asserts)
  local sd = Statsd:new({metrics_interval = 100})
  local metrics = createMetrics()
  metrics.timers['a'] = {100}
  metrics.timer_counters['a'] = 1
  metrics.pctThreshold = { 90, 80 }
  sd:_processMetrics(metrics, function(metrics)
    local timer_data = metrics.timer_data['a']
    asserts.equal(100, timer_data.mean_90)
    asserts.equal(100, timer_data.upper_90)
    asserts.equal(100, timer_data.sum_90)
    asserts.equal(100, timer_data.mean_80)
    asserts.equal(100, timer_data.upper_80)
    asserts.equal(100, timer_data.sum_80)
    test.done()
  end)
end

exports['test_timers_multiple_times_single_percentiles'] = function(test, asserts)
  local sd = Statsd:new({metrics_interval = 100})
  local metrics = createMetrics()
  metrics.timers['a'] = {100, 200, 300}
  metrics.timer_counters['a'] = 3
  metrics.pctThreshold = { 90 }
  sd:_processMetrics(metrics, function(metrics)
    local timer_data = metrics.timer_data['a']
    asserts.equal(200, timer_data.mean_90)
    asserts.equal(300, timer_data.upper_90)
    asserts.equal(600, timer_data.sum_90)
    test.done()
  end)
end

exports['test_timers_multiple_times_multiple_percentiles'] = function(test, asserts)
  local sd = Statsd:new({metrics_interval = 100})
  local metrics = createMetrics()
  metrics.timers['a'] = {100, 200, 300}
  metrics.timer_counters['a'] = 3
  metrics.pctThreshold = { 90, 80 }
  sd:_processMetrics(metrics, function(metrics)
    local timer_data = metrics.timer_data['a']
    asserts.equal(200, timer_data.mean_90)
    asserts.equal(300, timer_data.upper_90)
    asserts.equal(600, timer_data.sum_90)
    asserts.equal(150, timer_data.mean_80)
    asserts.equal(200, timer_data.upper_80)
    asserts.equal(300, timer_data.sum_80)
    test.done()
  end)
end

exports['test_timers_sampled_times'] = function(test, asserts)
  local sd = Statsd:new({metrics_interval = 100})
  local metrics = createMetrics()
  metrics.timers['a'] = {100, 200, 300}
  metrics.timer_counters['a'] = 50
  metrics.pctThreshold = { 90, 80 }
  sd:_processMetrics(metrics, function(metrics)
    local timer_data = metrics.timer_data['a']
    asserts.equal(50, timer_data.count)
    asserts.equal(500, timer_data.count_ps)
    asserts.equal(200, timer_data.mean_90)
    asserts.equal(300, timer_data.upper_90)
    asserts.equal(600, timer_data.sum_90)
    asserts.equal(150, timer_data.mean_80)
    asserts.equal(200, timer_data.upper_80)
    asserts.equal(300, timer_data.sum_80)
    test.done()
  end)
end

exports['test_timers_single_time_single_top_percentile'] = function(test, asserts)
  local sd = Statsd:new({metrics_interval = 100})
  local metrics = createMetrics()
  metrics.timers['a'] = {100}
  metrics.timer_counters['a'] = 1
  metrics.pctThreshold = { -10 }
  sd:_processMetrics(metrics, function(metrics)
    local timer_data = metrics.timer_data['a']
    asserts.equal(100, timer_data.mean_top10)
    asserts.equal(100, timer_data.lower_top10)
    asserts.equal(100, timer_data.sum_top10)
    test.done()
  end)
end

exports['test_timers_multiple_times_single_top_percentile'] = function(test, asserts)
  local sd = Statsd:new({metrics_interval = 100})
  local metrics = createMetrics()
  metrics.timers['a'] = {10, 10, 10, 10, 10, 10, 10, 10, 100, 200}
  metrics.timer_counters['a'] = 10
  metrics.pctThreshold = { -20 }
  sd:_processMetrics(metrics, function(metrics)
    local timer_data = metrics.timer_data['a']
    asserts.equal(150, timer_data.mean_top20);
    asserts.equal(100, timer_data.lower_top20);
    asserts.equal(300, timer_data.sum_top20);
    test.done()
  end)
end

exports['test_statsd_metrics_exist'] = function(test, asserts)
  local sd = Statsd:new({metrics_interval = 100})
  local metrics = createMetrics()
  sd:_processMetrics(metrics, function(metrics)
    asserts.ok(metrics.statsd_metrics.processing_time)
    test.done()
  end)
end

exports['test_version'] = function(test, asserts)
  asserts.ok(version)
  test.done()
end

return exports
