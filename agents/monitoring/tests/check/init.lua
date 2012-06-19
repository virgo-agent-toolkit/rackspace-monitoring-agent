--[[
Copyright 2012 Rackspace

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

local JSON = require('json')

local Check = require('monitoring/default/check')
local Metric = require('monitoring/default/check/base').Metric
local BaseCheck = Check.BaseCheck
local CheckResult = Check.CheckResult

local CpuCheck = Check.CpuCheck
local DiskCheck = Check.DiskCheck
local MemoryCheck = Check.MemoryCheck
local NetworkCheck = Check.NetworkCheck

exports = {}

exports['test_base_check'] = function(test, asserts)
  local check = BaseCheck:new({id='foo', period=30})
  asserts.ok(check._lastResults == nil)
  check:run(function(results)
    asserts.ok(results ~= nil)
    asserts.ok(check._lastResults ~= nil)
    asserts.ok(check._lastResults._nextRun)
    test.done()
  end)
end

exports['test_memory_check'] = function(test, asserts)
  local check = MemoryCheck:new({id='foo', period=30})
  asserts.ok(check._lastResults == nil)
  check:run(function(results)
    asserts.ok(results ~= nil)
    asserts.ok(check._lastResults ~= nil)
    asserts.ok(#check._lastResults:serialize() > 0)
    asserts.ok(check._lastResults._nextRun)
    test.done()
  end)
end

exports['test_cpu_check'] = function(test, asserts)
  local check = CpuCheck:new({id='foo', period=30})
  asserts.ok(check._lastResults == nil)
  check:run(function(results)
    asserts.ok(results ~= nil)
    asserts.ok(check._lastResults ~= nil)
    asserts.ok(#check._lastResults:serialize() > 0)
    asserts.ok(check._lastResults._nextRun)
    test.done()
  end)
end

exports['test_network_check'] = function(test, asserts)
  local check = NetworkCheck:new({id='foo', period=30})
  asserts.ok(check._lastResults == nil)
  check:run(function(results)
    asserts.ok(results ~= nil)
    asserts.ok(check._lastResults ~= nil)
    asserts.ok(#check._lastResults:serialize() > 0)
    asserts.ok(check._lastResults._nextRun)
    test.done()
  end)
end

exports['test_disks_check'] = function(test, asserts)
  local check = DiskCheck:new({id='foo', period=30})
  asserts.ok(check._lastResults == nil)
  check:run(function(results)
    asserts.ok(results ~= nil)
    asserts.ok(check._lastResults ~= nil)
    asserts.ok(#check._lastResults:serialize() > 0)
    asserts.ok(check._lastResults._nextRun)
    test.done()
  end)
end

exports['test_metric_type_detection_and_casting'] = function(test, asserts)
  local m1, m2, m3, m4, m5, g6

  m1 = Metric:new('test', 'eth0', nil, 5)
  m2 = Metric:new('test', nil, nil, 1.23456)
  m3 = Metric:new('test', nil, nil, 222.33)
  m4 = Metric:new('test', nil, nil, "foobar")
  m5 = Metric:new('test', nil, nil, true)
  m6 = Metric:new('test', nil, 'gauge', '2')

  asserts.throws(function() Metric:new('test', nil, 'invalidtype', '2') end)

  asserts.equals(m1.type, 'int64')
  asserts.equals(m2.type, 'double')
  asserts.equals(m3.type, 'double')
  asserts.equals(m4.type, 'string')
  asserts.equals(m5.type, 'bool')
  asserts.equals(m6.type, 'gauge')

  asserts.equals(m1.dimension, 'eth0')
  asserts.equals(m2.dimension, 'none')

  asserts.equals(m1.value, '5')
  asserts.equals(m2.value, '1.23456')
  asserts.equals(m3.value, '222.33')
  asserts.equals(m4.value, 'foobar')
  asserts.equals(m5.value, 'true')

  test.done()
end

exports['test_checkresult_serialization'] = function(test, asserts)
  local cr, serialized

  cr = CheckResult:new({id='foo', period=30})
  cr:addMetric('m1', nil, nil, 1.23456)
  cr:addMetric('m2', 'eth0', nil, 'test')

  serialized = cr:serialize()

  asserts.equals(#serialized, 2)
  asserts.equals(serialized[1][1], JSON.null)
  asserts.equals(serialized[1][2]['m1']['t'], 'double')
  asserts.equals(serialized[1][2]['m1']['v'], '1.23456')

  asserts.equals(serialized[2][1], 'eth0')
  asserts.equals(serialized[2][2]['m2']['t'], 'string')
  asserts.equals(serialized[2][2]['m2']['v'], 'test')

  test.done()
end

return exports
