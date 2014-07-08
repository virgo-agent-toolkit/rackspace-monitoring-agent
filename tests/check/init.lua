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
local fs = require('fs')
local async = require('async')

local string = require('string')

local fixtures = require('/tests/fixtures')
local Check = require('/check')
local Metric = require('/check/base').Metric
local constants = require('/constants')
local merge = require('/base/util/misc').merge
local msg = require ('/base/protocol/messages')
local virgoMsg = require('/protocol/virgo_messages')

local BaseCheck = Check.BaseCheck
local CheckResult = Check.CheckResult

local CpuCheck = Check.CpuCheck
local DiskCheck = Check.DiskCheck
local MemoryCheck = Check.MemoryCheck
local NetworkCheck = Check.NetworkCheck
local PluginCheck = Check.PluginCheck
local LoadAverageCheck = Check.LoadAverageCheck

local MySQLTests = require('./mysql')
local ApacheTests = require('./apache')
local FileSystemTests = require('./filesystem')
local LoadTests = require('./load_average')
local RedisTests = require('./redis')
local WindowsTests = require('./windows')

local exports = {}
exports = merge(exports, MySQLTests)
exports = merge(exports, ApacheTests)
exports = merge(exports, FileSystemTests)
exports = merge(exports, LoadTests)
exports = merge(exports, RedisTests)
exports = merge(exports, WindowsTests)

constants:setGlobal('DEFAULT_CUSTOM_PLUGINS_PATH', TEST_DIR)

local dump_check = function(name, perms, cb)
  local check = fixtures['custom_plugins'][name]
  if not check then
    return cb('no plugin named: ' .. name)
  end
  async.waterfall({
    function(cb)
      fs.open(path.join(TEST_DIR, name), 'w', perms, cb)
    end,
    function(fd, cb)
      fs.write(fd, 0, check, function(err, written)
        return cb(err, written, fd)
      end)
    end,
    function(written, fd, cb)
      if written ~= #check then
        return cb("did not write it all " .. written .. " " .. #check)
      end
      fs.close(fd, cb)
    end},
  cb)
end

local plugin_test = function(name, status, state, optional)
  local optional = optional or {}
  return function(test, asserts)
    local perms = optional.perms or '0777'
    local period = optional.period or 30
    local details = optional.details or {}
    details.file = name

    dump_check(name, perms, function(err, res)
      asserts.ok(err == nil, err)
      local check = PluginCheck:new({id=name, period=period, details=details})
      asserts.ok(check._lastResult == nil, check._lastResult)
      asserts.ok(check:toString():find('details'))
      check:run(function(result)
        asserts.ok(result ~= nil)
        asserts.equals(result:getStatus(), status, name)
        asserts.equals(result:getState(), state)
        if optional.cb then
          return optional.cb(test, asserts, result:getMetrics())
        end
        test.done()
      end)
    end)
  end
end

exports['test_base_check'] = function(test, asserts)
  local testcheck = BaseCheck:extend()
  function testcheck:getType()
    return "test"
  end
  function testcheck:initialize(params)
    BaseCheck.initialize(self, params)
  end
  local check = testcheck:new({id='foo', period=30})
  asserts.ok(check:getSummary() == '(id=foo, type=test)')
  asserts.ok(check:getSummary({foo = 'blah'}) == '(id=foo, type=test, foo=blah)')
  asserts.ok(check._lastResult == nil)
  check:run(function(result)
    asserts.ok(result ~= nil)
    asserts.ok(check._lastResult ~= nil)
    test.done()
  end)
end

exports['test_memory_check'] = function(test, asserts)
  local check = MemoryCheck:new({id='foo', period=30})
  asserts.ok(check._lastResult == nil)
  check:run(function(result)
    asserts.ok(result ~= nil)
    asserts.ok(check._lastResult ~= nil)
    asserts.ok(#check._lastResult:serialize() > 0)
    test.done()
  end)
end

exports['test_check'] = function(test, asserts)
  local checkParams = {
    id = 1,
    period = 30,
    type = 'agent.memory'
  }
  Check.test(checkParams, function(err, ch, result)
    asserts.ok(result ~= nil)
    test.done()
  end)
end

exports['test_check_invalid_type'] = function(test, asserts)
  local checkParams = {
    id = 1,
    period = 30,
    type = 'invalid.type'
  }
  Check.test(checkParams, function(err, ch, result)
    asserts.ok(err ~= nil)
    test.done()
  end)
end

exports['test_cpu_check'] = function(test, asserts)
  local check = CpuCheck:new({id='foo', period=30})
  asserts.ok(check._lastResult == nil)
  check:run(function(result)
    asserts.ok(result ~= nil)
    asserts.ok(check._lastResult ~= nil)
    asserts.ok(#check._lastResult:serialize() > 0)
    test.done()
  end)
end

local function assertsIsPercentage(asserts, value)
  local num = tonumber(value.v)
  return asserts.ok(num >= 0.0 and num <= 100.0)
end

exports['test_cpu_check_percentages'] = function(test, asserts)
  local check = CpuCheck:new({id='foo', period=30})
  asserts.ok(check._lastResult == nil)
  check:run(function(result)
    local obj = result:serialize()
    local cpu = obj[1]
    assertsIsPercentage(asserts, cpu[2].user_percent_average)
    assertsIsPercentage(asserts, cpu[2].usage_average)
    assertsIsPercentage(asserts, cpu[2].sys_percent_average)
    assertsIsPercentage(asserts, cpu[2].irq_percent_average)
    assertsIsPercentage(asserts, cpu[2].idle_percent_average)
    test.done()
  end)
end

exports['test_network_check_no_target'] = function(test, asserts)
  local check = NetworkCheck:new({id='foo', period=30})
  asserts.ok(check._lastResult == nil)
  check:run(function(result)
    asserts.ok(result ~= nil)
    asserts.equal(result:getState(), 'unavailable')
    asserts.equal(result:getStatus(), 'Missing target parameter; give me an interface.')
    test.done()
  end)
end

exports['test_network_check_target_does_not_exist'] = function(test, asserts)
  local check = NetworkCheck:new({id='foo', period=30, details={target='asdf'}})
  asserts.ok(check._lastResult == nil)
  check:run(function(result)
    asserts.ok(result ~= nil)
    asserts.equal(result:getState(), 'unavailable')
    asserts.equal(result:getStatus(), 'No such interface: asdf')
    test.done()
  end)
end

exports['test_network_check'] = function(test, asserts)
  local targets = {Linux='lo', Darwin='lo0'}
  local target = targets[os.type()] or "unknown"
  local check = NetworkCheck:new({id='foo', period=30, details={target=target}})
  asserts.ok(check._lastResult == nil)
  check:run(function(results)
    if target ~= "unknown" then
      -- Verify that no dimension is used
      local metrics = results:getMetrics()['none']

      asserts.not_nil(metrics['rx_errors']['v'])

      asserts.equal(results:getState(), 'available')
      asserts.ok(check._lastResult ~= nil)
      asserts.ok(#check._lastResult:serialize() > 0)
      test.done()
    else
      test.skip("Unknown interface target for " .. os.type())
    end
  end)
end

if not process.env['TRAVIS'] then
  exports['test_disks_check'] = function(test, asserts)
    DiskCheck:getTargets(function(err, targets)
      asserts.equals(err, nil)
      local check = DiskCheck:new({id='foo', period=30, details={target=targets[1]}})
      check:run(function(result)
        asserts.ok(result ~= nil)
        asserts.equal(result:getState(), 'available')
        local m = result:getMetrics()['none']
        asserts.not_nil(m)
        asserts.not_nil(m['reads'])
        asserts.not_nil(m['writes'])
        asserts.not_nil(m['read_bytes'])
        asserts.not_nil(m['write_bytes'])
        asserts.not_nil(m['rtime'])
        asserts.not_nil(m['wtime'])
        if os.type() ~= 'win32' then
          asserts.not_nil(m['qtime'])
          asserts.not_nil(m['time'])
        end
        asserts.not_nil(m['service_time'])
        asserts.not_nil(m['queue'])
        test.done()
      end)
    end)
  end
end

exports['test_disk_check_no_target'] = function(test, asserts)
  local check = DiskCheck:new({id='foo', period=30})
  check:run(function(result)
    asserts.ok(result ~= nil)
    asserts.equal(result:getState(), 'unavailable')
    asserts.equal(result:getStatus(), 'Missing target parameter')
    test.done()
  end)
end

exports['test_disk_check_target_does_not_exist'] = function(test, asserts)
  local check = DiskCheck:new({id='foo', period=30, details={target='does-not-exist'}})
  check:run(function(result)
    asserts.ok(result ~= nil)
    asserts.equal(result:getState(), 'unavailable')
    asserts.equal(result:getStatus(), 'No such disk: does-not-exist')
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

  -- Validate status truncation
  local max_length = constants:get('METRIC_STATUS_MAX_LENGTH')
  cr = CheckResult:new({id='foo', period=30})
  cr:setStatus(string.rep('a', max_length + 1))
  asserts.equals(#cr:getStatus(), max_length)

  cr:setStatus(string.rep('a', max_length - 10))
  asserts.equals(#cr:getStatus(), max_length - 10)

  test.done()
end

exports['test_custom_plugin_timeout'] = plugin_test('timeout.py',
  'Plugin didn\'t finish in 0.5 seconds', 'unavailable', {details={timeout=500}})

if os.type() == 'win32' then
  exports['test_custom_plugin_file_not_executable'] = function(test, asserts)
    return test.skip('Windows does not have an execute bit, just file associations')
  end
else
  exports['test_custom_plugin_file_not_executable'] = plugin_test('not_executable.sh',
    'Plugin exited with non-zero status code (code=-1)', 'unavailable', {perms='0444'})
end

exports['test_custom_plugin_non_zero_exit_code_with_status'] = plugin_test('non_zero_with_status.sh',
  'ponies > unicorns', 'unavailable')


exports['test_custom_plugin_file_doesnt_exist'] = function(test, asserts)
  local check = PluginCheck:new({id='foo', period=30, details={file='magical_ranibow_pony.sh'}})
  asserts.ok(check._lastResult == nil)
  check:run(function(result)
    asserts.ok(result ~= nil)
    -- This may be a libuv bug!
    if os.type() == "win32" then
      asserts.equals(result:getStatus(), 'Plugin exited with non-zero status code (code=127)')
    else
      asserts.equals(result:getStatus(), 'Plugin exited with non-zero status code (code=-1)')
    end
    asserts.equals(result:getState(), 'unavailable')
    test.done()
  end)
end

exports['test_custom_plugin_cmd_arguments'] = plugin_test('plugin_custom_arguments.sh',
  'arguments test', 'available', {details = {args = {'foo_bar', 'a', 'b', 'c'}}, cb = function(test, asserts, metrics)
    metrics = metrics['none']
    asserts.dequals(metrics['foo_bar'], {t = 'string', v = '0'})
    asserts.dequals(metrics['a'], {t = 'string', v = '1'})
    asserts.dequals(metrics['b'], {t ='string', v = '2'})
    asserts.dequals(metrics['c'], {t ='string', v = '3'})
    test.done()
  end}
)

exports['test_custom_plugin_all_types'] = plugin_test('plugin_1.sh',
  'Everything is OK', 'available', {cb = function(test, asserts, metrics)
    metrics = metrics['none']
    asserts.dequals(metrics['logged_users'], {t = 'int64', v = '7'})
    asserts.dequals(metrics['active_processes'], {t = 'int64', v = '200'})
    asserts.dequals(metrics['avg_wait_time'], {t = 'double', v = '100.7'})
    asserts.dequals(metrics['something'], {t = 'string', v = 'foo bar foo'})
    asserts.dequals(metrics['packet_count'], {t = 'gauge', v = '150000'})
    test.done()
  end}
)

exports['test_custom_plugin_all_types_reschedueling'] = function(test, asserts)
  -- Verify that custom plugin checks correctly re-schedule itself

  local check = PluginCheck:new({id='foo', period=30,
                                details={file='plugin_1.sh'}})
  local counter = 0
  asserts.ok(check._lastResult == nil)
  asserts.ok(check:toString():find('details'))

  check:schedule()
  check:on('completed', function(result)
    counter = counter + 1

    asserts.ok(result ~= nil)

    if counter == 3 then
      check:clearSchedule()
      test.done()
    end
  end)
end

exports['test_custom_plugin_dimensions'] = plugin_test('plugin_dimensions.sh',
  'Total logged users: 66', 'available', {cb = function(test, asserts, metrics)
    asserts.dequals(metrics['host1']['logged_users'], {t = 'int64', v = '10'})
    asserts.dequals(metrics['host2']['logged_users'], {t = 'int64', v = '17'})
    asserts.dequals(metrics['host3']['logged_users'], {t = 'int64', v = '10'})
    asserts.dequals(metrics['host4']['logged_users'], {t = 'int64', v = '22'})
    test.done()
  end}
)

exports['test_custom_plugin_metric_line_with_units'] = plugin_test('plugin_units.sh',
  'Total logged users: 66', 'available', {cb = function(test, asserts, metrics)
    metrics = metrics['host1']
    asserts.dequals(metrics['logged_users'], {t = 'int64', v = '66', u = 'users'})
    asserts.dequals(metrics['data_out'], {t = 'int64', v = '1024', u = 'bytes'})
    asserts.dequals(metrics['no_units'], {t = 'int64', v = '1'})
    test.done()
  end}
)

exports['test_custom_plugin_cloudkick_agent_plugin_backward_compatibility_1'] = plugin_test(
  'cloudkick_agent_custom_plugin_1.sh', 'Service is not responding', 'available',
    {cb = function(test, asserts, metrics)
    metrics = metrics['none']
    asserts.dequals(metrics['legacy_state'], {t = 'string', v = 'err'})
    asserts.dequals(metrics['logged_users'], {t = 'int64', v = '7'})
    asserts.dequals(metrics['active_processes'], {t = 'int64', v = '200'})
    test.done()
  end}
)

exports['test_custom_plugin_cloudkick_agent_plugin_backward_compatibility_2'] = plugin_test(
  'cloudkick_agent_custom_plugin_2.sh', '', 'available', {cb = function(test, asserts, metrics)
    metrics = metrics['none']
    asserts.dequals(metrics['legacy_state'], {t = 'string', v = 'warn'})
    asserts.dequals(metrics['logged_users'], {t = 'int64', v = '7'})
    asserts.dequals(metrics['active_processes'], {t = 'int64', v = '200'})
    test.done()
  end}
)

exports['test_custom_plugin_repeated_status_line'] = function(test, asserts)
  if os.type() == 'win32' then
    return test.skip('Unsupported Platform for custom plugins')
  end

  local counter = 0

  dump_check('repeated_status_line.sh', "0777", function(err)
    local check = PluginCheck:new({id='foo', period=30, details={file='repeated_status_line.sh'}})
    asserts.ok(check._lastResult == nil)

    check:schedule()
    check:on('completed', function(check, result)
      local metrics = result:getMetrics()
      counter = counter + 1

      asserts.ok(result ~= nil)
      asserts.equals(result:getStatus(), 'First status line')
      asserts.equals(result:getState(), 'available')
      asserts.ok(result:getTimestamp() > 1343400000)

      asserts.dequals(metrics['none']['logged_users'], {t = 'int64', v = '7'})
      asserts.dequals(metrics['none']['active_processes'], {t = 'int64', v = '200'})

      if counter == 3 then
        check:clearSchedule()
        test.done()
      end
    end)
  end)
end

exports['test_custom_plugin_partial_output_sleep'] = plugin_test('partial_output_with_sleep.sh',
  'Everything is OK', 'available', {cb = function(test, asserts, metrics)
    metrics = metrics['none']
    asserts.dequals(metrics['logged_users'], {t = 'int64', v = '7'})
    asserts.dequals(metrics['active_processes'], {t = 'int64', v = '200'})
    asserts.dequals(metrics['avg_wait_time'], {t = 'double', v = '100.7'})
    asserts.dequals(metrics['something'], {t = 'string', v = 'foo bar foo'})
    asserts.dequals(metrics['packet_count'], {t = 'gauge', v = '150000'})
    test.done()
  end})

exports['test_custom_plugin_invalid_metric_line_invalid_metric_type'] = plugin_test(
  'invalid_metric_lines_1.sh', 'Invalid type "intfoo" for metric "metric1"', 'unavailable',
    {cb = function(test, asserts, metrics)
    asserts.dequals(metrics, {})
    test.done()
  end}
)

exports['test_custom_plugin_invalid_metric_line_not_a_valid_format'] = plugin_test(
  'invalid_metric_lines_2.sh', 'Metric line not in the following format: metric <name> <type> <value> [<unit>]',
  'unavailable', {cb = function(test, asserts, metrics)
    asserts.dequals(metrics, {})
    test.done()
  end}
)

exports['test_custom_plugin_invalid_metric_line_invalid_value_for_non_string_metric'] = plugin_test(
  'invalid_metric_lines_3.sh', 'Invalid "<value> [<unit>]" combination "100 200 bytes" for a non-string metric',
  'unavailable',{cb = function(test, asserts, metrics)
    asserts.dequals(metrics, {})
    test.done()
  end}
)

exports['test_custom_plugin_invalid_metric_line_unrecognized_line'] = plugin_test(
  'invalid_metric_lines_4.sh', 'Unrecognized line "some unknown line"',
  'unavailable', {cb = function(test, asserts, metrics)
    asserts.dequals(metrics, {})
    test.done()
  end}
)

if os.type() == 'win32' then
  exports['test_custom_plugin_windows_batch_file'] = plugin_test(
    'windows1.bat', 'Test plugin is OK',
    'available', {cb = function(test, asserts, metrics)
      asserts.dequals(metrics['none']['metric1'], {t = 'int64', v = '1'})
      asserts.dequals(metrics['none']['metric2'], {t = 'int64', v = '100'})
      test.done()
    end}
  )

  exports['test_custom_plugin_windows_ps_file'] = plugin_test(
    'windows2.ps1', 'Test plugin is OK',
    'available', {cb = function(test, asserts, metrics)
      asserts.dequals(metrics['none']['metric1'], {t = 'int64', v = '1'})
      asserts.dequals(metrics['none']['metric2'], {t = 'int64', v = '100'})
      test.done()
    end}
  )
else
  exports['test_custom_plugin_windows_batch_file'] = function(test, asserts)
    return test.skip('test_custom_plugin_windows_batch_file is Windows Only')
  end
  exports['test_custom_plugin_windows_ps_file'] = function(test, asserts)
    return test.skip('test_custom_plugin_windows_ps_file is Windows Only')
  end
end

exports['test_check_metrics_post_serialization'] = function(test, asserts)
  local check = MemoryCheck:new({id='foo', period=30})
  asserts.ok(check._lastResult == nil)
  check:run(function(result)
    local check_metrics_post = virgoMsg.MetricsRequest:new(check, result)
    local serialized = check_metrics_post:serialize()
    asserts.ok(serialized.params.timestamp > 1343400000)
    asserts.equals(serialized.params.check_type, 'agent.memory')
    asserts.equals(serialized.params.check_id, 'foo')
    asserts.equals(serialized.params.metrics[1][2].swap_free.u, 'bytes')
    test.done()
  end)
end

return exports
