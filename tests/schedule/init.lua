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
local string = require('string')

local Scheduler = require('monitoring/default/schedule').Scheduler
local BaseCheck = require('monitoring/default/check/base').BaseCheck
local NullCheck = require('monitoring/default/check/null').NullCheck
local misc = require('monitoring/default/util/misc')

local exports = {}

local function make_check(...)
  local args = unpack({...})
  local check_path = path.join(TEST_DIR, string.format("%s.chk", args.check_path or args.id))
  local period = args.period or 1
  local state = args.state or 'OK'
  return BaseCheck:new('test', {["id"]=id, ["state"]=state, ["period"]=period, ["path"]=check_path})
end

exports['test_scheduler_scans'] = function(test, asserts)
  local checks = {
    make_check{id='ch0001'},
    make_check{id='ch0002'},
    make_check{id='ch0003'},
    make_check{id='ch0004'},
  }

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
  local checks = {
    make_check{id='ch0001'}
  }
  local new_checks = {
    make_check{id='ch0001'},
    make_check{id='ch0002'}
  }

  async.waterfall({
    function(callback)
      scheduler = Scheduler:new(checks)
      scheduler:start()
      process.nextTick(callback)
    end,
    function(callback)
      local count = 0
      callback = misc.fireOnce(callback)
      scheduler:rebuild(new_checks)
      scheduler:on('check.completed', function()
        count = count + 1
        if count == 3 then
          callback()
        end
      end)
    end
  }, function(err)
    asserts.equals(scheduler:numChecks(), 2)
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
