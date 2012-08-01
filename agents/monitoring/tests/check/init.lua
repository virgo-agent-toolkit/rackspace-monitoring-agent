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
local path = require('path')
local os = require('os')

local Check = require('monitoring/default/check')
local Metric = require('monitoring/default/check/base').Metric
local constants = require('monitoring/default/util/constants')
local BaseCheck = Check.BaseCheck
local CheckResult = Check.CheckResult

local CpuCheck = Check.CpuCheck
local DiskCheck = Check.DiskCheck
local MemoryCheck = Check.MemoryCheck
local NetworkCheck = Check.NetworkCheck
local PluginCheck = Check.PluginCheck

exports = {}

exports['test_base_check'] = function(test, asserts)
  local check = BaseCheck:new('test', {id='foo', period=30})
  asserts.ok(check._lastResult == nil)
  check:run(function(results)
    asserts.ok(results ~= nil)
    asserts.ok(check._lastResult ~= nil)
    asserts.ok(check._lastResult._nextRun)
    test.done()
  end)
end

exports['test_memory_check'] = function(test, asserts)
  local check = MemoryCheck:new({id='foo', period=30})
  asserts.ok(check._lastResult == nil)
  check:run(function(results)
    asserts.ok(results ~= nil)
    asserts.ok(check._lastResult ~= nil)
    asserts.ok(#check._lastResult:serialize() > 0)
    asserts.ok(check._lastResult._nextRun)
    test.done()
  end)
end

exports['test_check'] = function(test, asserts)
  local checkParams = {
    id = 1,
    period = 30,
    type = 'agent.memory'
  }
  Check.test(checkParams, function(err, ch, results)
    asserts.ok(results ~= nil)
    test.done()
  end)
end

exports['test_check_invalid_type'] = function(test, asserts)
  local checkParams = {
    id = 1,
    period = 30,
    type = 'invalid.type'
  }
  Check.test(checkParams, function(err, ch, results)
    asserts.ok(err ~= nil)
    test.done()
  end)
end

exports['test_cpu_check'] = function(test, asserts)
  local check = CpuCheck:new({id='foo', period=30})
  asserts.ok(check._lastResult == nil)
  check:run(function(results)
    asserts.ok(results ~= nil)
    asserts.ok(check._lastResult ~= nil)
    asserts.ok(#check._lastResult:serialize() > 0)
    asserts.ok(check._lastResult._nextRun)
    test.done()
  end)
end

exports['test_network_check'] = function(test, asserts)
  local check = NetworkCheck:new({id='foo', period=30})
  asserts.ok(check._lastResult == nil)
  check:run(function(results)
    asserts.ok(results ~= nil)
    asserts.ok(check._lastResult ~= nil)
    asserts.ok(#check._lastResult:serialize() > 0)
    asserts.ok(check._lastResult._nextRun)
    test.done()
  end)
end

exports['test_disks_check'] = function(test, asserts)
  local check = DiskCheck:new({id='foo', period=30})
  asserts.ok(check._lastResult == nil)
  check:run(function(results)
    asserts.ok(results ~= nil)
    asserts.ok(check._lastResult ~= nil)
    asserts.ok(#check._lastResult:serialize() > 0)
    asserts.ok(check._lastResult._nextRun)
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

exports['test_custom_plugin_timeout'] = function(test, asserts)
  constants.DEFAULT_CUSTOM_PLUGINS_PATH = path.join(process.cwd(),
                      '/agents/monitoring/tests/fixtures/custom_plugins')

  local check = PluginCheck:new({id='foo', period=30,
                                details={timeout=500, file='timeout.py'}})
  asserts.ok(check._lastResults == nil)
  check:run(function(result)
    asserts.ok(result ~= nil)
    asserts.equals(result:getStatus(), 'Plugin didn\'t finish in 0.5 seconds')
    asserts.equals(result:getState(), 'unavailable')
    test.done()
  end)
end

exports['test_custom_plugin_file_not_executable'] = function(test, asserts)
  if os.type() == "win32" then
    test.skip("Unsupported Platform for custom plugins")
    return
  end

  constants.DEFAULT_CUSTOM_PLUGINS_PATH = path.join(process.cwd(),
                      '/agents/monitoring/tests/fixtures/custom_plugins')

  local check = PluginCheck:new({id='foo', period=30,
                                 details={file='not_executable.sh'}})
  asserts.ok(check._lastResults == nil)
  check:run(function(result)
    asserts.ok(result ~= nil)
    asserts.equals(result:getStatus(), 'Plugin exited with non-zero status code (code=127)')
    asserts.equals(result:getState(), 'unavailable')
    test.done()
  end)
end

exports['test_custom_plugin_file_doesnt_exist'] = function(test, asserts)
  constants.DEFAULT_CUSTOM_PLUGINS_PATH = path.join(process.cwd(),
                      '/agents/monitoring/tests/fixtures/custom_plugins')

  local check = PluginCheck:new({id='foo', period=30,
                                 details={file='doesnt_exist.sh'}})
  asserts.ok(check._lastResults == nil)
  check:run(function(result)
    asserts.ok(result ~= nil)
    asserts.equals(result:getStatus(), 'Plugin exited with non-zero status code (code=127)')
    asserts.equals(result:getState(), 'unavailable')
    test.done()
  end)
end

exports['test_custom_plugin_cmd_arguments'] = function(test, asserts)
  constants.DEFAULT_CUSTOM_PLUGINS_PATH = path.join(process.cwd(),
                      '/agents/monitoring/tests/fixtures/custom_plugins')

  local check = PluginCheck:new({id='foo', period=30,
                                 details={file='plugin_custom_arguments.sh',
                                 args={'foo_bar', 'a', 'b', 'c'}}})
  asserts.ok(check._lastResults == nil)
  check:run(function(result)
    local metrics = result:getMetrics()['none']

    asserts.ok(result ~= nil)
    asserts.equals(result:getStatus(), 'arguments test')
    asserts.equals(result:getState(), 'available')

    asserts.dequals(metrics['foo_bar'], {t = 'string', v = '0'})
    asserts.dequals(metrics['a'], {t = 'string', v = '1'})
    asserts.dequals(metrics['b'], {t ='string', v = '2'})
    asserts.dequals(metrics['c'], {t ='string', v = '3'})
    test.done()
  end)
end

exports['test_custom_plugin_all_types'] = function(test, asserts)
  constants.DEFAULT_CUSTOM_PLUGINS_PATH = path.join(process.cwd(),
                      '/agents/monitoring/tests/fixtures/custom_plugins')

  local check = PluginCheck:new({id='foo', period=30,
                                details={file='plugin_1.sh'}})
  asserts.ok(check._lastResults == nil)
  check:run(function(result)
    local metrics = result:getMetrics()['none']

    asserts.ok(result ~= nil)
    asserts.equals(result:getStatus(), 'Everything is OK')
    asserts.equals(result:getState(), 'available')

    asserts.dequals(metrics['logged_users'], {t = 'int64', v = '7'})
    asserts.dequals(metrics['active_processes'], {t = 'int64', v = '200'})
    asserts.dequals(metrics['avg_wait_time'], {t = 'double', v = '100.7'})
    asserts.dequals(metrics['something'], {t = 'string', v = 'foo bar foo'})
    asserts.dequals(metrics['packet_count'], {t = 'gauge', v = '150000'})
    test.done()
  end)
end

exports['test_custom_plugin_dimensions'] = function(test, asserts)
  constants.DEFAULT_CUSTOM_PLUGINS_PATH = path.join(process.cwd(),
                      '/agents/monitoring/tests/fixtures/custom_plugins')

  local check = PluginCheck:new({id='foo', period=30,
                                 details={file='plugin_dimensions.sh'}})
  asserts.ok(check._lastResults == nil)
  check:run(function(result)
    local metrics = result:getMetrics()

    asserts.ok(result ~= nil)
    asserts.equals(result:getStatus(), 'Total logged users: 66')
    asserts.equals(result:getState(), 'available')

    asserts.dequals(metrics['host1']['logged_users'], {t = 'int64', v = '10'})
    asserts.dequals(metrics['host2']['logged_users'], {t = 'int64', v = '17'})
    asserts.dequals(metrics['host3']['logged_users'], {t = 'int64', v = '10'})
    asserts.dequals(metrics['host4']['logged_users'], {t = 'int64', v = '22'})
    test.done()
  end)
end

exports['test_custom_plugin_cloudkick_agent_plugin_backward_compatibility_1'] = function(test, asserts)
  constants.DEFAULT_CUSTOM_PLUGINS_PATH = path.join(process.cwd(),
                      '/agents/monitoring/tests/fixtures/custom_plugins')

  local check = PluginCheck:new({id='foo', period=30,
                                 details={file='cloudkick_agent_custom_plugin_1.sh'}})
  asserts.ok(check._lastResults == nil)
  check:run(function(result)
    local metrics = result:getMetrics()

    asserts.ok(result ~= nil)
    asserts.equals(result:getStatus(), 'Service is not responding')
    asserts.equals(result:getState(), 'available')

    asserts.dequals(metrics['none']['logged_users'], {t = 'int64', v = '7'})
    asserts.dequals(metrics['none']['active_processes'], {t = 'int64', v = '200'})
    test.done()
  end)
end

exports['test_custom_plugin_cloudkick_agent_plugin_backward_compatibility_2'] = function(test, asserts)
  constants.DEFAULT_CUSTOM_PLUGINS_PATH = path.join(process.cwd(),
                      '/agents/monitoring/tests/fixtures/custom_plugins')

  local check = PluginCheck:new({id='foo', period=30,
                                 details={file='cloudkick_agent_custom_plugin_2.sh'}})
  asserts.ok(check._lastResults == nil)
  check:run(function(result)
    local metrics = result:getMetrics()

    asserts.ok(result ~= nil)
    asserts.equals(result:getStatus(), '')
    asserts.equals(result:getState(), 'available')

    asserts.dequals(metrics['none']['logged_users'], {t = 'int64', v = '7'})
    asserts.dequals(metrics['none']['active_processes'], {t = 'int64', v = '200'})
    test.done()
  end)
end

exports['test_custom_plugin_repeated_status_line'] = function(test, asserts)
  constants.DEFAULT_CUSTOM_PLUGINS_PATH = path.join(process.cwd(),
                      '/agents/monitoring/tests/fixtures/custom_plugins')

  local check = PluginCheck:new({id='foo', period=30,
                                 details={file='repeated_status_line.sh'}})
  asserts.ok(check._lastResults == nil)
  check:run(function(result)
    local metrics = result:getMetrics()

    asserts.ok(result ~= nil)
    asserts.equals(result:getStatus(), 'First status line')
    asserts.equals(result:getState(), 'available')

    asserts.dequals(metrics['none']['logged_users'], {t = 'int64', v = '7'})
    asserts.dequals(metrics['none']['active_processes'], {t = 'int64', v = '200'})
    test.done()
  end)
end

exports['test_custom_plugin_partial_output_sleep'] = function(test, asserts)
  constants.DEFAULT_CUSTOM_PLUGINS_PATH = path.join(process.cwd(),
                      '/agents/monitoring/tests/fixtures/custom_plugins')

  local check = PluginCheck:new({id='foo', period=30,
                                 details={file='partial_output_with_sleep.sh'}})
  asserts.ok(check._lastResults == nil)
  check:run(function(result)
    local metrics = result:getMetrics()['none']

    asserts.ok(result ~= nil)
    asserts.equals(result:getStatus(), 'Everything is OK')
    asserts.equals(result:getState(), 'available')

    asserts.dequals(metrics['logged_users'], {t = 'int64', v = '7'})
    asserts.dequals(metrics['active_processes'], {t = 'int64', v = '200'})
    asserts.dequals(metrics['avg_wait_time'], {t = 'double', v = '100.7'})
    asserts.dequals(metrics['something'], {t = 'string', v = 'foo bar foo'})
    asserts.dequals(metrics['packet_count'], {t = 'gauge', v = '150000'})
    test.done()
  end)
end

exports['test_custom_plugin_invalid_metric_line_invalid_metric_type'] = function(test, asserts)
  constants.DEFAULT_CUSTOM_PLUGINS_PATH = path.join(process.cwd(),
                      '/agents/monitoring/tests/fixtures/custom_plugins')

  local check = PluginCheck:new({id='foo', period=30,
                                 details={file='invalid_metric_lines_1.sh'}})
  asserts.ok(check._lastResults == nil)
  check:run(function(result)
    local metrics = result:getMetrics()

    asserts.ok(result ~= nil)
    asserts.equals(result:getStatus(), 'Invalid type "intfoo" for metric "metric1"')
    asserts.equals(result:getState(), 'unavailable')

    asserts.dequals(metrics, {})
    test.done()
  end)
end

exports['test_custom_plugin_invalid_metric_line_not_a_valid_format'] = function(test, asserts)
  constants.DEFAULT_CUSTOM_PLUGINS_PATH = path.join(process.cwd(),
                      '/agents/monitoring/tests/fixtures/custom_plugins')

  local check = PluginCheck:new({id='foo', period=30,
                                 details={file='invalid_metric_lines_2.sh'}})
  asserts.ok(check._lastResults == nil)
  check:run(function(result)
    local metrics = result:getMetrics()

    asserts.ok(result ~= nil)
    asserts.equals(result:getStatus(), 'Metric line not in the following format: metric <name> <type> <value>')
    asserts.equals(result:getState(), 'unavailable')

    asserts.dequals(metrics, {})
    test.done()
  end)
end

exports['test_custom_plugin_invalid_metric_line_invalid_value_for_non_string_metric'] = function(test, asserts)
  constants.DEFAULT_CUSTOM_PLUGINS_PATH = path.join(process.cwd(),
                      '/agents/monitoring/tests/fixtures/custom_plugins')

  local check = PluginCheck:new({id='foo', period=30,
                                 details={file='invalid_metric_lines_3.sh'}})
  asserts.ok(check._lastResults == nil)
  check:run(function(result)
    local metrics = result:getMetrics()

    asserts.ok(result ~= nil)
    asserts.equals(result:getStatus(), 'Invalid value "100 200" for a non-string metric')
    asserts.equals(result:getState(), 'unavailable')

    asserts.dequals(metrics, {})
    test.done()
  end)
end

exports['test_custom_plugin_invalid_metric_line_unrecognized_line'] = function(test, asserts)
  constants.DEFAULT_CUSTOM_PLUGINS_PATH = path.join(process.cwd(),
                      '/agents/monitoring/tests/fixtures/custom_plugins')

  local check = PluginCheck:new({id='foo', period=30,
                                 details={file='invalid_metric_lines_4.sh'}})
  asserts.ok(check._lastResults == nil)
  check:run(function(result)
    local metrics = result:getMetrics()

    asserts.ok(result ~= nil)
    asserts.equals(result:getStatus(), 'Unrecognized line "some unknown line"')
    asserts.equals(result:getState(), 'unavailable')

    asserts.dequals(metrics, {})
    test.done()
  end)
end

return exports
