--[[
Copyright 2015 Rackspace

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

local async = require('async')
local constants = require('../constants')
local env = require('env')
local fixtures = require('./fixtures')
local fs = require('fs')
local los = require('los')
local path = require('path')
local timer = require('timer')
local uv = require('uv')
local BaseCheck = require('../check/base').BaseCheck
local Check = require('../check')
local CheckResult = require('../check').CheckResult
local CpuCheck = require('../check/cpu').CpuCheck
local DiskCheck = require('../check/disk').DiskCheck
local MemoryCheck = require('../check/memory').MemoryCheck
local MetricsRequest = require('../protocol/virgo_messages').MetricsRequest
local Metric = require('../check/base').Metric
local NetworkCheck = require('../check/network').NetworkCheck
local PluginCheck = require('../check/plugin').PluginCheck
_G.TEST_DIR = 'tests/tmpdir'
constants:setGlobal('DEFAULT_CUSTOM_PLUGINS_PATH', _G.TEST_DIR)

require('tap')(function(test)
  test('test check base', function(expect)
    local testcheck = BaseCheck:extend()
    function testcheck:getType()
      return "test"
    end
    function testcheck:initialize(params)
      BaseCheck.initialize(self, params)
    end
    local check = testcheck:new({id='foo', period=30})
    assert(check:getSummary() == '(id=foo, type=test)')
    assert(check:getSummary({foo = 'blah'}) == '(id=foo, type=test, foo=blah)')
    assert(not check._lastResult)
    check:run(expect(function(result)
      assert(result)
      assert(check._lastResult)
    end))
  end)

  test('test check memory', function(expect)
    local check = MemoryCheck:new({id='foo', period=30})
    assert(not check._lastResult)
    check:run(expect(function(result)
      assert(result)
      assert(check._lastResult)
      assert(#check._lastResult:serialize() > 0)
    end))
  end)

  test('test check', function(expect)
    local checkParams = {
      id = 1,
      period = 30,
      type = 'agent.memory'
    }
    Check.test(checkParams, expect(function(err, ch, result)
      assert(result)
    end))
  end)

  test('test check invalid type', function(expect)
    local checkParams = {
      id = 1,
      period = 30,
      type = 'invalid.type'
    }
    Check.test(checkParams, expect(function(err, ch, result)
      assert(err)
    end))
  end)

  test('test check cpu', function(expect)
    local check = CpuCheck:new({id='foo', period=30})
    assert(not check._lastResult)
    check:run(expect(function(result)
      local obj = result:serialize()
      local cpu = obj[1]
      assert(result ~= nil)
      assert(check._lastResult ~= nil)
      assert(cpu[2].cpu_count ~= nil)
      assert(#check._lastResult:serialize() > 0)
    end))
  end)

  test('test check cpu percentages', function(expect)
    local function assertsIsPercentage(value)
      local num = tonumber(value.v)
      return assert(num >= 0.0 and num <= 100.0)
    end
    local check = CpuCheck:new({id='foo', period=30})
    assert(check._lastResult == nil)
    check:run(expect(function(result)
      local obj = result:serialize()
      local cpu = obj[1]
      assertsIsPercentage(cpu[2].user_percent_average)
      assertsIsPercentage(cpu[2].usage_average)
      assertsIsPercentage(cpu[2].sys_percent_average)
      assertsIsPercentage(cpu[2].irq_percent_average)
      assertsIsPercentage(cpu[2].idle_percent_average)
    end))
  end)

  test('test check network no target', function(expect)
    local check = NetworkCheck:new({id='foo', period=30})
    assert(not check._lastResult)
    check:run(expect(function(result)
      assert(result ~= nil)
      assert(result:getState() == 'unavailable')
      assert(result:getStatus() == 'Missing target parameter; give me an interface.')
    end))
  end)

  test('test check network target does not exist', function(expect)
    local check = NetworkCheck:new({id='foo', period=30, details={target='asdf'}})
    assert(not check._lastResult)
    check:run(expect(function(result)
      assert(result)
      assert(result:getState() == 'unavailable')
      assert(result:getStatus() == 'No such interface: asdf')
    end))
  end)

  test('test check network', function(expect)
    local targets = {linux='lo', darwin='lo0'}
    local target = targets[los.type()] or "unknown"
    local check = NetworkCheck:new({id='foo', period=30, details={target=target}})
    assert(not check._lastResult)
    check:run(expect(function(results)
      if target ~= "unknown" then
        -- Verify that no dimension is used
        local metrics = results:getMetrics()['none']
        assert(metrics['rx_errors']['v'])
        assert(results:getState() == 'available')
        assert(check._lastResult)
        assert(#check._lastResult:serialize() > 0)
      else
        p('unknown interface target for ' .. los.type())
      end
    end))
  end)

  test('test disks check', function(expect)
    if env.get('TRAVIS') then p('skipping on travis') ; return end
    DiskCheck:getTargets(expect(function(err, targets)
      assert(not err)
      local check = DiskCheck:new({id='foo', period=30, details={target=targets[1]}})
      check:run(function(result)
        assert(result)
        assert(result:getState() == 'available')
        local m = result:getMetrics()['none']
        assert(m)
        assert(m['reads'])
        assert(m['writes'])
        assert(m['read_bytes'])
        assert(m['write_bytes'])
        assert(m['rtime'])
        assert(m['wtime'])
        assert(m['service_time'])
        assert(m['queue'])
        if los.type() ~= 'win32' then
          assert(m['qtime'])
          assert(m['time'])
        end
      end)
    end))
  end)

  test('test check disk no target', function(expect)
    local check = DiskCheck:new({id='foo', period=30})
    check:run(expect(function(result)
      assert(result)
      assert(result:getState() == 'unavailable')
      assert(result:getStatus() == 'Missing target parameter')
    end))
  end)

  test('test check disk target does not exist', function(expect)
    local check = DiskCheck:new({id='foo', period=30, details={target='does-not-exist'}})
    check:run(expect(function(result)
      assert(result)
      assert(result:getState() == 'unavailable')
      assert(result:getStatus() == 'No such disk: does-not-exist')
    end))
  end)

  test('test metric type detection and casting', function(expect)
    local m1, m2, m3, m4, m5, m6

    m1 = Metric:new('test', 'eth0', nil, 5)
    m2 = Metric:new('test', nil, nil, 1.23456)
    m3 = Metric:new('test', nil, nil, 222.33)
    m4 = Metric:new('test', nil, nil, "foobar")
    m5 = Metric:new('test', nil, nil, true)
    m6 = Metric:new('test', nil, 'gauge', '2')

    assert(m1.type == 'int64')
    assert(m2.type == 'double')
    assert(m3.type == 'double')
    assert(m4.type == 'string')
    assert(m5.type == 'bool')
    assert(m6.type == 'gauge')

    assert(m1.dimension == 'eth0')
    assert(m2.dimension == 'none')

    assert(m1.value == '5')
    assert(m2.value == '1.23456')
    assert(m3.value == '222.33')
    assert(m4.value == 'foobar')
    assert(m5.value == 'true')
  end)

  test('test check result serialization', function(expect)
    local cr, serialized

    cr = CheckResult:new({id='foo', period=30})
    cr:addMetric('m1', nil, nil, 1.23456)
    cr:addMetric('m2', 'eth0', nil, 'test')
    serialized = cr:serialize()

    assert(#serialized == 2)
    assert(serialized[1][2]['m1']['t'] == 'double')
    assert(serialized[1][2]['m1']['v'] == '1.23456')

    assert(serialized[2][1] == 'eth0')
    assert(serialized[2][2]['m2']['t'] == 'string')
    assert(serialized[2][2]['m2']['v'] == 'test')

    -- Validate status truncation
    local max_length = constants:get('METRIC_STATUS_MAX_LENGTH')
    cr = CheckResult:new({id='foo', period=30})
    cr:setStatus(string.rep('a', max_length + 1))
    assert(#cr:getStatus() == max_length)

    cr:setStatus(string.rep('a', max_length - 10))
    assert(#cr:getStatus() == max_length - 10)
  end)

  test('test check metrics post serialization', function(expect)
    local check = MemoryCheck:new({id='foo', period=30})
    assert(not check._lastResult)
    check:run(expect(function(result)
      local check_metrics_post = MetricsRequest:new(check, result)
      local serialized = check_metrics_post:serialize()
      assert(serialized.params.timestamp > 1343400000)
      assert(serialized.params.check_type == 'agent.memory')
      assert(serialized.params.check_id == 'foo')
      assert(serialized.params.metrics[1][2].swap_free.u == 'bytes')
    end))
  end)

    local dump_check = function(name, perms, cb)
      local check = fixtures['custom_plugins'][path.basename(name)]
      if not check then
        return cb('no plugin named: ' .. name)
      end
      async.waterfall({
        function(cb)
          local dirname = path.dirname(name)
          if not dirname then return cb() end
          fs.mkdir(path.join(TEST_DIR, dirname), function(err)
            if err then
              if err:match('^EEXIST') then return cb() end
              return cb(err)
            end
            cb()
          end)
        end,
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

    local function plugin_test(name, status, state, optional, expect)
      optional = optional or {}
      local perms = optional.perms or '0777'
      local period = optional.period or 30
      local details = optional.details or {}
      details.file = name

      local function onResult(result)
        assert(result)
        assert(result:getStatus() == status, status)
        assert(result:getState() == state, state)
        if optional.cb then
          return optional.cb(result:getMetrics())
        end
      end

      local function onDump(err, res)
        assert(not err, err)
        local check = PluginCheck:new({id=name, period=period, details=details})
        assert(check._lastResult == nil, check._lastResult)
        assert(check:toString():find('details'))
        check:run(expect(onResult))
      end

      dump_check(name, perms, expect(onDump))
    end

  test('test custom plugin timeout', function(expect)
    if los.type() == 'win32' then p('skipped') ; return end
    plugin_test('timeout.sh','Plugin did not finish in 0.5 seconds',
            'available', { details = {
              timeout=500
            }, cb = expect(function(metrics)
                assert(metrics['timeout']['time_out_dur'].t == 'double', "time_out_dur should be double!")
                local num1 = metrics['timeout']['time_out_dur'].v
                local num = tonumber(num1)
                p('Metric Timeout duration = ' .. num )
                assert(num <= 0.5, 'Plugin did not finish in 0.5 seconds...')
              end)
            },
            expect)
  end)

  test('test custom plugin file not executable', function(expect)
    p('skipped')
    --if los.type() == 'win32' then p('skipped') ; return end
    --plugin_test('not_executable.sh', 'Plugin exited with non-zero status code (code=-127)',
    --   'unavailable', {perms='0444'}, expect)
  end)

  test('test custom plugin non zero exit code with status', function(expect)
    if los.type() == 'win32' then p('skipped') ; return end
    plugin_test('non_zero_with_status.sh', 'ponies > unicorns',
      'unavailable', nil, expect)
  end)

  test('test custom plugin file does not exist', function(expect)
    if los.type() == 'win32' then p('skipped') ; return end
    local check = PluginCheck:new({id='foo', period=30, details={file='magical_ranibow_pony.sh'}})
    assert(not check._lastResult)
    check:run(expect(function(result)
      assert(result)
      assert(result:getStatus() == 'Plugin exited with non-zero status code (code=-127)')
      assert(result:getState() == 'unavailable')
    end))
  end)

  test('test custom plugin cmd arguments', function(expect)
    if los.type() == 'win32' then p('skipped') ; return end
    plugin_test('plugin_custom_arguments.sh', 'arguments test', 'available', {
      details = {
        args = {'foo_bar', 'a', 'b', 'c'}
      },
      cb = expect(function(metrics)
        metrics = metrics['none']
        assert(metrics['foo_bar'].t == 'string')
        assert(metrics['foo_bar'].v == '0')
        assert(metrics['a'].t == 'string')
        assert(metrics['a'].v == '1')
        assert(metrics['b'].t == 'string')
        assert(metrics['b'].v == '2')
        assert(metrics['c'].t == 'string')
        assert(metrics['c'].v == '3')
      end)
    }, expect)
  end)

  test('test custom plugin all types', function(expect)
    if los.type() == 'win32' then p('skipped') ; return end
    plugin_test('plugin_1.sh', 'Everything is OK', 'available', {
      cb = expect(function(metrics)
        metrics = metrics['none']
        assert(metrics['logged_users'].t == 'int64')
        assert(metrics['logged_users'].v == '0x7')
        assert(metrics['active_processes'].t == 'int64')
        assert(metrics['active_processes'].v == '0xc8')
        assert(metrics['avg_wait_time'].t == 'double')
        assert(metrics['avg_wait_time'].v == '100.7')
        assert(metrics['something'].t == 'string')
        assert(metrics['something'].v == 'foo bar foo')
        assert(metrics['packet_count'].t == 'gauge')
        assert(metrics['packet_count'].v == '0x249f0')
      end)
    }, expect)
  end)

  test('test custom plugin all types (subfolder)', function(expect)
    if los.type() == 'win32' then p('skipped') ; return end
    plugin_test('subfolder/plugin_1.sh', 'Everything is OK', 'available', {
      cb = expect(function(metrics)
        metrics = metrics['none']
        assert(metrics['logged_users'].t == 'int64')
        assert(metrics['logged_users'].v == '0x7')
        assert(metrics['active_processes'].t == 'int64')
        assert(metrics['active_processes'].v == '0xc8')
        assert(metrics['avg_wait_time'].t == 'double')
        assert(metrics['avg_wait_time'].v == '100.7')
        assert(metrics['something'].t == 'string')
        assert(metrics['something'].v == 'foo bar foo')
        assert(metrics['packet_count'].t == 'gauge')
        assert(metrics['packet_count'].v == '0x249f0')
      end)
    }, expect)
  end)

  test('test custom plugin all types rescheduling', function(expect)
    if los.type() == 'win32' then p('skipped') ; return end
    local check = PluginCheck:new({id='foo', period=2,
                                  details={file='plugin_1.sh'}})
    local counter, onCompleted
    counter = 0
    assert(not check._lastResult)
    assert(check:toString():find('details'))

    function onCompleted(result)
      counter = counter + 1
      assert(result)
      if counter == 2 then check:clearSchedule() end
    end

    check:schedule()
    check:on('completed', onCompleted)
  end)

  test('test custom plugin dimensions', function(expect)
    if los.type() == 'win32' then p('skipped') ; return end
    plugin_test('plugin_dimensions.sh', 'Total logged users: 66', 'available', {
      cb = expect(function(metrics)
        assert(metrics['host1']['logged_users'].t == 'int64')
        assert(metrics['host1']['logged_users'].v == '0xa')
        assert(metrics['host2']['logged_users'].t == 'int64')
        assert(metrics['host2']['logged_users'].v == '0x11')
        assert(metrics['host3']['logged_users'].t == 'int64')
        assert(metrics['host3']['logged_users'].v == '0xa')
        assert(metrics['host4']['logged_users'].t == 'int64')
        assert(metrics['host4']['logged_users'].v == '0x16')
      end)
    }, expect)
  end)

  test('test custom plugin metric line units', function(expect)
    if los.type() == 'win32' then p('skipped') ; return end
    plugin_test('plugin_units.sh', 'Total logged users: 66', 'available', {
      cb = expect(function(metrics)
        metrics = metrics['host1']
        assert(metrics['logged_users'].v == '0x42')
        assert(metrics['logged_users'].t == 'int64')
        assert(metrics['logged_users'].u == 'users')
        assert(metrics['data_out'].u == 'bytes')
        assert(metrics['data_out'].t == 'int64')
        assert(metrics['data_out'].v == '0x400')
        assert(metrics['no_units'].t == 'int64')
        assert(metrics['no_units'].v == '0x1')
      end)
    }, expect)
  end)

  test('test custom plugin cloudkick agent plugin backwards', function(expect)
    if los.type() == 'win32' then p('skipped') ; return end
    plugin_test('cloudkick_agent_custom_plugin_1.sh', 'Service is not responding', 'available', {
      cb = expect(function(metrics)
        metrics = metrics['none']
        assert(metrics['legacy_state'].t == 'string')
        assert(metrics['legacy_state'].v == 'err')
        assert(metrics['logged_users'].t == 'int64')
        assert(metrics['logged_users'].v == '0x7')
        assert(metrics['active_processes'].t == 'int64')
        assert(metrics['active_processes'].v == '0xc8')
      end)
    }, expect)
  end)

  test('test custom plugin cloudkick agent plugin backwards 2', function(expect)
    if los.type() == 'win32' then p('skipped') ; return end
    plugin_test('cloudkick_agent_custom_plugin_2.sh', '', 'available', {
      cb = expect(function(metrics)
        metrics = metrics['none']
        assert(metrics['legacy_state'].t == 'string')
        assert(metrics['legacy_state'].v == 'warn')
        assert(metrics['logged_users'].t == 'int64')
        assert(metrics['logged_users'].v == '0x7')
        assert(metrics['active_processes'].t == 'int64')
        assert(metrics['active_processes'].v == '0xc8')
      end)
    }, expect)
  end)

  test('test custom plugin partial output sleep', function(expect)
    if los.type() == 'win32' then p('skipped') ; return end
    plugin_test('partial_output_with_sleep.sh', 'Everything is OK', 'available', {
      cb = expect(function(metrics)
        metrics = metrics['none']
        assert(metrics['logged_users'].t == 'int64')
        assert(metrics['logged_users'].v == '0x7')
        assert(metrics['active_processes'].t == 'int64')
        assert(metrics['active_processes'].v == '0xc8')
        assert(metrics['avg_wait_time'].t == 'double')
        assert(metrics['avg_wait_time'].v == '100.7')
        assert(metrics['something'].t == 'string')
        assert(metrics['something'].v == 'foo bar foo')
        assert(metrics['packet_count'].t == 'gauge')
        assert(metrics['packet_count'].v == '0x249f0')
      end)
    }, expect)
  end)

  test('test custom plugin lots of data', function(expect)
    if los.type() == 'win32' then p('skipped') ; return end
    plugin_test('lots_of_data.sh', 'Everything is OK', 'available', {
      cb = expect(function(metrics)
        metrics = metrics['none']
        assert(metrics['logged_users_aaa'].t == 'int64')
        assert(metrics['logged_users_aaa'].v == '0x7')
      end)
    }, expect)
  end)


  test('test custom plugin invalid metric line invalid metric type', function(expect)
    if los.type() == 'win32' then p('skipped') ; return end
    plugin_test('invalid_metric_lines_1.sh', 'Invalid type "intfoo" for metric "metric1"', 'unavailable', {
      cb = expect(function(metrics)
        assert(#metrics == 0)
      end)
    }, expect)
  end)

  test('test custom plugin invalid metric line not a valid format', function(expect)
    if los.type() == 'win32' then p('skipped') ; return end
    plugin_test('invalid_metric_lines_2.sh', 'Metric line not in the following format: metric <name> <type> <value> [<unit>]', 'unavailable', {
      cb = expect(function(metrics)
        assert(#metrics == 0)
      end)
    }, expect)
  end)

  test('test custom plugin invalid value for non string metric', function(expect)
    if los.type() == 'win32' then p('skipped') ; return end
    plugin_test('invalid_metric_lines_3.sh', 'Invalid "<value> [<unit>]" combination "100 200 bytes" for a non-string metric', 'unavailable', {
      cb = expect(function(metrics)
        assert(#metrics == 0)
      end)
    }, expect)
  end)

  test('test custom plugin invalid value for unrecognized line', function(expect)
    if los.type() == 'win32' then p('skipped') ; return end
    plugin_test('invalid_metric_lines_4.sh', 'Unrecognized line "some unknown line"', 'unavailable', {
      cb = expect(function(metrics)
        assert(#metrics == 0)
      end)
    }, expect)
  end)

  test('test custom plugin windows batch file', function(expect)
    if los.type() ~= 'win32' then p('skipped') ; return end
    plugin_test('windows1.bat', 'Test plugin is OK', 'available', {
      cb = expect(function(metrics)
        assert(metrics['none']['metric1'].t == 'int64')
        assert(metrics['none']['metric2'].v == '0x64')
      end)
    }, expect)
  end)

  test('test custom plugin windows batch file (subfolder)', function(expect)
    if los.type() ~= 'win32' then p('skipped') ; return end
    plugin_test('dummyfolder\\windows1.bat', 'Test plugin is OK', 'available', {
      cb = expect(function(metrics)
        assert(metrics['none']['metric1'].t == 'int64')
        assert(metrics['none']['metric2'].v == '0x64')
      end)
    }, expect)
  end)

  test('test custom plugin powershell', function(expect)
    if los.type() ~= 'win32' then p('skipped') ; return end
    plugin_test('windows2.ps1', 'Test plugin is OK', 'available', {
      cb = expect(function(metrics)
        assert(metrics['none']['metric1'].t == 'int64')
        assert(metrics['none']['metric2'].v == '0x64')
      end)
    }, expect)
  end)
end)
