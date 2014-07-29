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
local Uuid = require('/base/util/uuid')
local splitAddress = require('/base/util/misc').splitAddress
local writePid = require('/base/util/misc').writePid
local lastIndexOf = require('/base/util/misc').lastIndexOf
local compareVersions = require('/base/util/misc').compareVersions
local os = require('os')
local logging = require('logging')
local native = require('uv_native')
local constants = require('constants')
local timer = require('timer')

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
  if os.type() == "win32" then
    local err = virgo.write_pid(path)
    asserts.ok(err ~= nil)
    test.done()
  else
    local err = virgo.write_pid(path)
    asserts.equals(err, nil)
    fs.readFile(path, function(err, data)
      asserts.equals(err, nil)
      local pid = data
      asserts.equals(pid, tostring(process.pid))
      virgo.close_pid()
      test.done()
    end)
  end
end

exports['test_gmtnow'] = function(test, asserts)
  local now = virgo.gmtnow()
  asserts.ok(now ~= nil)
  test.done()
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

exports['test_versions'] = function(test, asserts)
  asserts.equals(compareVersions('0.0.0', '0.0.0'), 0)
  asserts.equals(compareVersions('0.0.1', '0.0.0'), 1)
  asserts.equals(compareVersions('1.0.0', '1.0.0'), 0)
  asserts.equals(compareVersions('1.0.0', '1.0.25'), -1)
  asserts.equals(compareVersions('1.0.25.25', '1.0.25'), 1)
  asserts.equals(compareVersions('1.0.0', '1.0.25.1'), -1)
  asserts.equals(compareVersions('9.0.0', '1.0.0'), 1)
  asserts.equals(compareVersions('9.0.0-1', '9.0.0-2'), -1)
  asserts.equals(compareVersions('9.0.0-2', '9.0.0-2'), 0)
  asserts.equals(compareVersions('9.0.0-2', '9.0.0-1'), 1)
  asserts.equals(compareVersions('0.1.7-164', '0.1.7-53'), 1)
  test.done()
end

exports['test_virgo_signals'] = function(test, asserts)
  if os.type() == "win32" then
    test.skip("Signal Not Supported on Win32")
  else
    local orig_level = logging.get_level()
    logging.set_level(logging.INFO)
    native.kill(native.getpid(), constants.SIGUSR2)

    local i = 0
    timer.setInterval(1, function()
      i = i + 1
      if i == 5 then
        local new_level = logging.get_level()
        logging.set_level(orig_level)

        asserts.equal(new_level, logging.EVERYTHING, "Logging should be set to EVERYTHING")
      end
    end)

    test.done()
  end
end

return exports
