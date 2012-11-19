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

local Scheduler = require('monitoring/default/schedule').Scheduler
local BaseCheck = require('monitoring/default/check/base').BaseCheck
local NullCheck = require('monitoring/default/check/null').NullCheck
local misc = require('monitoring/default/util/misc')
local tmp = path.join('tests', 'tmp')

local exports = {}

local checks = {
  BaseCheck:new('test', {id='ch0001', state='OK', period=1, path=path.join(tmp, '0001.chk')}),
  BaseCheck:new('test', {id='ch0002', state='OK', period=1, path=path.join(tmp, '0002.chk')}),
  BaseCheck:new('test', {id='ch0003', state='OK', period=1, path=path.join(tmp, '0003.chk')}),
  BaseCheck:new('test', {id='ch0004', state='OK', period=1, path=path.join(tmp, '0004.chk')}),
}

exports['test_scheduler_scans'] = function(test, asserts)
  local scheduler = Scheduler:new(checks)

  async.waterfall({
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
  local scheduler
local checks2 = {
  BaseCheck:new('test', {id='ch0001', state='OK', period=1, path=path.join(tmp, '0001.chk')}),
}
local checks3 = {
  BaseCheck:new('test', {id='ch0001', state='OK', period=1, path=path.join(tmp, '0001.chk')}),
  BaseCheck:new('test', {id='ch0002', state='OK', period=1, path=path.join(tmp, '0002.chk')}),
}
local checks4 = {
  BaseCheck:new('test', {id='ch0002', state='OK', period=1, path=path.join(tmp, '0002.chk')}),
}
local checks5 = {
  BaseCheck:new('test', {id='ch0002', state='OK', period=1, path=path.join(tmp, '0002.chk')}),
}
local checks6 = {
  BaseCheck:new('test', {id='ch0001', state='OK', period=1, path=path.join(tmp, '0001.chk')}),
}
local checks7 = {
  BaseCheck:new('test', {id='ch0001', state='OK', period=2, path=path.join(tmp, '0002.chk')}),
}


  async.waterfall({
    function(callback)
      scheduler = Scheduler:new(checks2)
      scheduler:start()
      process.nextTick(callback)
    end,
    function(callback)
      local count = 0
      callback = misc.fireOnce(callback)
      scheduler:rebuild(checks3)
      scheduler:on('check.completed', function()
        count = count + 1
        if count == 3 then
          callback()
        end
      end)
    end
  }, function(err)
    asserts.equals(scheduler:numChecks(), 3)
    scheduler:stop()
    asserts.ok(err == nil)
    test.done()
  end)
end

exports['test_scheduler_timeout'] = function(test, asserts)
  local scheduler
  local checks
  local done = misc.fireOnce(function()
    scheduler:stop()
    test.done()
  end)

  checks = {
    NullCheck:new({id='ch0001', state='OK', period=3}),
  }

  checks[1]:on('timeout', done)
  scheduler = Scheduler:new(checks)
  scheduler:start()
  
end

return exports
