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

local path = require('path')
local async = require('async')
local utils = require('utils')
local timer = require('timer')

local StateScanner = require('monitoring/default/schedule').StateScanner
local Scheduler = require('monitoring/default/schedule').Scheduler
local BaseCheck = require('monitoring/default/check/base').BaseCheck
local tmp = path.join('tests', 'tmp')

local exports = {}

local checks = {
  BaseCheck:new({id='ch0001', state='OK', period=1, path=path.join(tmp, '0001.chk')}),
  BaseCheck:new({id='ch0002', state='OK', period=1, path=path.join(tmp, '0002.chk')}),
  BaseCheck:new({id='ch0003', state='OK', period=1, path=path.join(tmp, '0003.chk')}),
  BaseCheck:new({id='ch0004', state='OK', period=1, path=path.join(tmp, '0004.chk')}),
}

exports['test_scheduler_scan'] = function(test, asserts)
  local s = StateScanner:new(process.cwd()..'/agents/monitoring/tests/data/sample.state')
  local count = 0
  s:on('check_scheduled', function(details)
    count = count + 1
    if count >= 3 then
      s:stop()
      test.done()
    end
  end)
  s:scanStates()
end

exports['test_scheduler_initialize'] = function(test, asserts)
  local testFile = path.join(tmp, 'test_scheduler_initialize.state')

  async.waterfall({
    -- write a scan file. the scheduler does this.
    function(callback)
      Scheduler:new(testFile, checks, callback)
    end,

    -- load with scanner.
    function(callback)
      local count = 0
      local s = StateScanner:new(testFile)
      s:on('check_scheduled', function(details)
        count = count + 1
        if count >= #checks then
          s:stop()
          callback()
        end
      end)
      s:scanStates()
    end
  }, function(err)
    asserts.ok(err == nil)
    test.done()
  end)
end


exports['test_scheduler_scans'] = function(test, asserts)
  local testFile = path.join(tmp, 'test_scheduler_scans.state')
  local scheduler

  async.waterfall({
    function(callback)
      scheduler = Scheduler:new(testFile, checks, callback)
    end,
    function(callback)
      scheduler:start()
      local timeout = timer.setTimeout(5000, function()
        -- they all should have run.
        asserts.ok(scheduler._runCount > 0)
        callback()
      end)
    end
  }, function(err)
    scheduler:stop()
    asserts.ok(err == nil)
    test.done()
  end)
end


exports['test_scheduler_adds'] = function(test, asserts)
  local testFile = path.join(tmp, 'test_scheduler_adds.state')
  local scheduler
local checks2 = {
  BaseCheck:new({id='ch0001', state='OK', period=1, path=path.join(tmp, '0001.chk')}),
}
local checks3 = {
  BaseCheck:new({id='ch0001', state='OK', period=1, path=path.join(tmp, '0001.chk')}),
  BaseCheck:new({id='ch0002', state='OK', period=1, path=path.join(tmp, '0002.chk')}),
}
local checks4 = {
  BaseCheck:new({id='ch0002', state='OK', period=1, path=path.join(tmp, '0002.chk')}),
}
local checks5 = {
  BaseCheck:new({id='ch0002', state='OK', period=1, path=path.join(tmp, '0002.chk')}),
}
local checks6 = {
  BaseCheck:new({id='ch0001', state='OK', period=1, path=path.join(tmp, '0001.chk')}),
}
local checks7 = {
  BaseCheck:new({id='ch0001', state='OK', period=2, path=path.join(tmp, '0002.chk')}),
}
  local lastRun = 0
  async.waterfall({
    function(callback)
      scheduler = Scheduler:new(testFile, checks2, callback)
    end,
    function(callback)
      scheduler:rebuild(checks3, callback)
    end,
    function(callback)
      scheduler:start()
      local timeout = timer.setTimeout(2000, function()
        -- they all should have run.
        asserts.equals(scheduler._runCount, 6)
        lastRun = scheduler._runCount
        asserts.equals(scheduler:numChecks(), 3)
        scheduler:rebuild(checks4, callback);
      end)
    end
  }, function(err)
    scheduler:stop()
    if err then
      p(err)
    end
    asserts.ok(err == nil)
    test.done()
  end)
end


return exports
