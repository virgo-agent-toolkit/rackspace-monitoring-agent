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

local async = require('async')
local utils = require('utils')

local StateScanner = require('monitoring/lib/schedule').StateScanner
local Scheduler = require('monitoring/lib/schedule').Scheduler
local BaseCheck = require('monitoring/lib/check/base').BaseCheck

local exports = {}

exports['test_scheduler_scan'] = function(test, asserts)
  local s = StateScanner:new('/data/virgo/agents/monitoring/tests/data/sample.state')
  local count = 0
  s:on('check_scheduled', function(details)
    count = count + 1
    if count >= 3 then
      test.done()
    end
  end)
  s:scanStates()
end

exports['test_scheduler_initialize'] = function(test, asserts)
  local checks = {
    BaseCheck:new({id='ch0001', state='OK'}),
    BaseCheck:new({id='ch0002', state='OK'}),
    BaseCheck:new({id='ch0003', state='OK'}),
    BaseCheck:new({id='ch0004', state='OK'}),
  }
  local testFile = '/tmp/test_checks_0001.state'
  
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

return exports