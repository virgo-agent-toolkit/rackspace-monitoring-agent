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
local Uuid = require('monitoring/default/util/uuid')
local splitAddress = require('monitoring/default/util/misc').splitAddress
local writePid = require('monitoring/default/util/misc').writePid
local lastIndexOf = require('monitoring/default/util/misc').lastIndexOf

exports['test_uuid_generation'] = function(test, asserts)
  local uuid1 = Uuid:new('01:02:ba:cd:32:6d')
  local uuid2 = Uuid:new('01:02:ba:cd:32:6d')

  -- string reps should be different.
  asserts.ok(uuid1:toString() ~= uuid2:toString())
  -- last chunk should be the same.
  asserts.equals(uuid1:toString():reverse():sub(1, 10), uuid2:toString():reverse():sub(1, 10))
  test.done()
end

exports['test_pid'] = function(test, asserts)
  local path = 'test.pid'
  writePid(path, function(err)
    asserts.equals(err, nil)
    fs.readFile(path, function(err, data)
      asserts.equals(err, nil)
      local pid = data
      asserts.equals(pid, tostring(process.pid))
      fs.unlink(path, function(err)
        asserts.equals(err, nil)
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

exports['test_lastIndexOf'] = function(test, asserts)
  asserts.equals(lastIndexOf('foo', 'bar'), nil)
  asserts.equals(lastIndexOf('foo', 'foo'), 1)
  asserts.equals(lastIndexOf('.test.foo.bar', '%.'), 10)
  test.done()
end

return exports
