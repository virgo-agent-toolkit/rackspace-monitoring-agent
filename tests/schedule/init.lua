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

local Emitter = require('core').Emitter
local Scheduler = require('/schedule').Scheduler
local BaseCheck = require('/check/base').BaseCheck
local ChildCheck = require('/check/base').ChildCheck
local NullCheck = require('/check/null').NullCheck
local Check = require('/check')
local misc = require('/base/util/misc')

local PluginCheck = Check.PluginCheck

local exports = {}

local function make_check(...)
  local args = unpack({...})
  local check_path = path.join(TEST_DIR, string.format("%s.chk", args.check_path or args.id))
  local period = args.period or 1
  local id = args.id or 'NOID'
  local state = args.state or 'OK'
  local test_check = BaseCheck:extend()
  function test_check:getType()
    return "test"
  end
  return test_check:new({["id"]=id, ["state"]=state, ["period"]=period, ["path"]=check_path})
end

exports['test_scheduler_scans'] = function(test, asserts)
  local checks = {
    make_check{id='ch0001'},
    make_check{id='ch0002'},
    make_check{id='ch0003'},
    make_check{id='ch0004'},
  }

  local scheduler = Scheduler:new()
  scheduler:start()
  scheduler:rebuild(checks)

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
      scheduler = Scheduler:new()
      scheduler:start()
      scheduler:rebuild(checks)
      process.nextTick(callback)
    end,
    function(callback)
      scheduler:rebuild(new_checks)
      scheduler:on('check.completed', misc.nCallbacks(callback, 2))
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
  scheduler = Scheduler:new()
  scheduler:start()
  scheduler:rebuild(checks)
end

local CheckCollection = Emitter:extend()
function CheckCollection:initialize(scheduler, checks)
  self.scheduler = scheduler
  self.checks = checks
end

local function createWaitForEvent(eventName)
  return function(self, count, callback)
    local function done()
      self.scheduler:removeListener(eventName)
      process.nextTick(callback)
    end
    local cb = misc.nCallbacks(done, count)
    self.scheduler:on(eventName, cb)
  end
end

CheckCollection.waitForCreated = createWaitForEvent('check.created')
CheckCollection.waitForModified = createWaitForEvent('check.modified')
CheckCollection.waitForDeleted = createWaitForEvent('check.deleted')

function CheckCollection:waitForCheckCompleted(count, callback)
  local function done()
    self.scheduler:removeListener('check.completed')
    callback()
  end
  local cb = misc.nCallbacks(done, count)
  self.scheduler:on('check.completed', function(check)
    local found = false
    for _, v in ipairs(self.checks) do
      if v.id == check.id then
        found = true
      end
    end
    assert(found == true)
    cb()
  end)
end


exports['test_scheduler_custom_check_reload'] = function(test, asserts)
  local scheduler, create, update, remove

  scheduler = Scheduler:new()
  scheduler:start()

  create = CheckCollection:new(scheduler, {
    PluginCheck:new({id='ch0001', state='OK', period=3, details={file='plugin_1.sh'}})
  })

  update = CheckCollection:new(scheduler, {
    PluginCheck:new({id='ch0001', state='OK', period=3, details={file='plugin_1.sh', args={'arg1'}}})
  })

  remove = CheckCollection:new(scheduler, {})

  async.series({
    function(callback)
      create:waitForCreated(1, callback)
      scheduler:rebuild(create.checks)
    end,
    function(callback)
      create:waitForCheckCompleted(3, callback)
    end,
    function(callback)
      update:waitForModified(1, callback)
      scheduler:rebuild(update.checks)
    end,
    function(callback)
      create:waitForCheckCompleted(3, callback)
    end,
    function(callback)
      local checkMap = scheduler:getCheckMap()
      asserts.ok(checkMap['ch0001']:toString():find('arg1') ~= nil)
      callback()
    end,
    function(callback)
      remove:waitForDeleted(1, callback)
      scheduler:rebuild(remove.checks)
    end,
    function(callback)
      asserts.ok(scheduler:numChecks() == 0)
      asserts.ok(scheduler:runCheck() > 0)
      callback()
    end
  }, function(err)
    scheduler:stop()
    test.done()
  end)
end

exports['test_scheduler_custom_check_reload_multiple'] = function(test, asserts)
  local scheduler, create, remove

  scheduler = Scheduler:new()
  scheduler:start()

  create = CheckCollection:new(scheduler, {
    PluginCheck:new({id='ch0001', state='OK', period=3, details={file='plugin_1.sh'}}),
    PluginCheck:new({id='ch0002', state='OK', period=3, details={file='plugin_2.sh'}})
  })

  remove = CheckCollection:new(scheduler, {
    PluginCheck:new({id='ch0001', state='OK', period=3, details={file='plugin_1.sh', args={'arg1'}}})
  })

  async.series({
    function(callback)
      create:waitForCreated(2, callback)
      scheduler:rebuild(create.checks)
    end,
    function(callback)
      remove:waitForModified(1, callback)
      scheduler:rebuild(remove.checks)
    end,
    function(callback)
      local checkMap = scheduler:getCheckMap()
      asserts.ok(checkMap['ch0002'] == nil)
      asserts.ok(checkMap['ch0001']:toString():find('arg1') ~= nil)
      callback()
    end,
    function(callback)
      remove:waitForCheckCompleted(5, callback)
    end
  }, function(err)
    scheduler:stop()
    test.done()
  end)
end

exports['test_scheduler_custom_check_reload'] = function(test, asserts)
  local scheduler, create, update, remove

  scheduler = Scheduler:new()
  scheduler:start()

  create = CheckCollection:new(scheduler, {
    PluginCheck:new({id='ch0001', state='OK', period=3, details={file='plugin_1.sh'}})
  })

  update = CheckCollection:new(scheduler, {
    PluginCheck:new({id='ch0001', state='OK', period=3, details={file='plugin_1.sh', args={'arg1'}}})
  })

  remove = CheckCollection:new(scheduler, {})

  async.series({
    function(callback)
      create:waitForCreated(1, callback)
      scheduler:rebuild(create.checks)
    end,
    function(callback)
      create:waitForCheckCompleted(3, callback)
    end,
    function(callback)
      update:waitForModified(1, callback)
      scheduler:rebuild(update.checks)
    end,
    function(callback)
      create:waitForCheckCompleted(3, callback)
    end,
    function(callback)
      local checkMap = scheduler:getCheckMap()
      asserts.ok(checkMap['ch0001']:toString():find('arg1') ~= nil)
      callback()
    end,
    function(callback)
      remove:waitForDeleted(1, callback)
      scheduler:rebuild(remove)
    end,
    function(callback)
      asserts.ok(scheduler:numChecks() == 0)
      asserts.ok(scheduler:runCheck() > 0)
      callback()
    end
  }, function(err)
    scheduler:stop()
    test.done()
  end)
end

exports['test_scheduler_custom_check_reload_multiple_adds_removes'] = function(test, asserts)
  local scheduler, create1, remove1, remove2, create2

  scheduler = Scheduler:new()
  scheduler:start()

  create1 = CheckCollection:new(scheduler, {
    PluginCheck:new({id='ch0001', state='OK', period=3, details={file='plugin_1.sh'}}),
    PluginCheck:new({id='ch0002', state='OK', period=3, details={file='plugin_2.sh'}})
  })

  remove1 = CheckCollection:new(scheduler, {
    PluginCheck:new({id='ch0001', state='OK', period=3, details={file='plugin_1.sh', args={'arg1'}}})
  })

  remove2 = CheckCollection:new(scheduler, {})

  create2 = CheckCollection:new(scheduler, {
    PluginCheck:new({id='ch0003', state='OK', period=3, details={file='plugin_3.sh'}})
  })

  async.series({
    function(callback)
      create1:waitForCreated(2, callback)
      scheduler:rebuild(create1.checks)
    end,
    function(callback)
      remove1:waitForModified(1, callback)
      scheduler:rebuild(remove1.checks)
    end,
    function(callback)
      remove1:waitForCheckCompleted(2, callback)
    end,
    function(callback)
      remove2:waitForDeleted(1, callback)
      scheduler:rebuild(remove2.checks)
    end,
    function(callback)
      create2:waitForCreated(1, callback)
      scheduler:rebuild(create2.checks)
    end,
    function(callback)
      create2:waitForCheckCompleted(2, callback)
    end,
    function(callback)
      asserts.ok(scheduler:numChecks() == 1)
      local checkMap = scheduler:getCheckMap()
      asserts.ok(checkMap['ch0003']:toString() ~= nil)
      asserts.ok(checkMap['ch0002'] == nil)
      asserts.ok(checkMap['ch0001'] == nil)
      callback()
    end
  }, function(err)
    scheduler:stop()
    test.done()
  end)
end

exports['test_scheduler_plugin_file_update'] = function(test, asserts)
  local scheduler, create, update 

  scheduler = Scheduler:new()
  scheduler:start()

  create = CheckCollection:new(scheduler, {
    PluginCheck:new({id='ch0001', state='OK', period=3, details={file='plugin_1.sh'}}),
  })

  update = CheckCollection:new(scheduler, {
    PluginCheck:new({id='ch0001', state='OK', period=3, details={file='plugin_2.sh', args={'arg1'}}})
  })

  async.series({
    function(callback)
      create:waitForCreated(1, callback)
      scheduler:rebuild(create.checks)
    end,
    function(callback)
      update:waitForModified(1, callback)
      scheduler:rebuild(update.checks)
    end,
    function(callback)
      local checkMap = scheduler:getCheckMap()
      asserts.ok(checkMap['ch0001']:toString():find('plugin_2') ~= nil)
      callback()
    end,
    function(callback)
      update:waitForCheckCompleted(5, callback)
    end
  }, function(err)
    scheduler:stop()
    test.done()
  end)
end

return exports
