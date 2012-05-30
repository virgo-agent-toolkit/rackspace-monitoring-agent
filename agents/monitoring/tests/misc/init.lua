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

exports = {}
no = {}

local fs = require('fs')
local Uuid = require('monitoring/lib/util/uuid')
local splitAddress = require('monitoring/lib/util/misc').splitAddress
local writepid = require('monitoring/monitoring-agent').WritePid

exports['test_uuid_generation'] = function(test, asserts)
  local uuid1 = Uuid:new('01:02:ba:cd:32:6d')
  local uuid2 = Uuid:new('01:02:ba:cd:32:6d')

  -- string reps should be different.
  asserts.ok(uuid1:toString() ~= uuid2:toString())
  -- last chunk should be the same.
  asserts.equals(uuid1:toString():reverse():sub(1, 10), uuid2:toString():reverse():sub(1, 10))
  test.done()
end

exports['test_pid'] = function(test)
  local path = 'test.pid'
  writepid(path, function(err)
    assert(err == nil)
    fs.readFile(path, function(err, data)
      assert(err == nil)
      pid = data
      assert(pid == tostring(process.pid), 'PID File Written Unsuccessfully')
      fs.unlink(path, function(err)
        assert(err == nil)
        test.done()
      end)
    end)
  end)
end

exports['test_splitAddress'] = function(test, asserts)
  local valid = '127.0.0.1:6000'
  local invalid = '127.0.0.2'
  local result = {'127.0.0.1', 6000}

  asserts.equals(splitAddress(valid)[1], result[1])
  asserts.equals(splitAddress(valid)[2], result[2])
  asserts.equals(splitAddress(invalid), null)
  test.done()
end

return exports
