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

local Check = require('monitoring/lib/check')
local BaseCheck = Check.BaseCheck
local CheckResult = Check.CheckResult

local CpuCheck = Check.CpuCheck
local DiskCheck = Check.DiskCheck
local MemoryCheck = Check.MemoryCheck
local NetworkCheck = Check.NetworkCheck

exports = {}

exports['test_base_check'] = function(test, asserts)
  local check = BaseCheck:new({id='foo', state='OK', period=30})
  asserts.ok(check._lastResults == nil)
  check:run(function(results)
    asserts.ok(results ~= nil)
    asserts.ok(check._lastResults ~= nil)
    asserts.ok(check._lastResults._nextRun)
    test.done()
  end)
end

exports['test_memory_check'] = function(test, asserts)
  local check = MemoryCheck:new({id='foo', state='OK', period=30})
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
  local check = CpuCheck:new({id='foo', state='OK', period=30})
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
  local check = NetworkCheck:new({id='foo', state='OK', period=30})
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
  local check = DiskCheck:new({id='foo', state='OK', period=30})
  asserts.ok(check._lastResults == nil)
  check:run(function(results)
    asserts.ok(results ~= nil)
    asserts.ok(check._lastResults ~= nil)
    asserts.ok(#check._lastResults:serialize() > 0)
    asserts.ok(check._lastResults._nextRun)
    test.done()
  end)
end

return exports
