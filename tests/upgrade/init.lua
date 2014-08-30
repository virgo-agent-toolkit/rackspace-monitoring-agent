--[[
Copyright 2013 Rackspace
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
local exec = require('virgo_exec')
local string = require('string')
local upgrade = require('/base/client/upgrade')
local path = require('path')
local async = require('async')
local fs = require('fs')
local fixtures = require('/tests/fixtures')

local exports = {}
local testexe = '0001.sh'

local function createOptions(bExe, myVersion)
  return {
    ['b'] = { ['exe'] = bExe },
    my_version = myVersion,
    pretend = true
  }
end

local setupExe = function(dir, name, perms, cb)
  local exe = fixtures['upgrade'][name]
  if not exe then
    return cb('no exe named: ' .. name)
  end
  async.waterfall({
    function(cb)
      fs.open(path.join(dir, name), 'w', perms, cb)
    end,
    function(fd, cb)
      fs.write(fd, 0, exe, function(err, written)
        return cb(err, written, fd)
      end)
    end,
    function(written, fd, cb)
      if written ~= #exe then
        return cb("did not write it all " .. written .. " " .. #exe)
      end
      fs.close(fd, cb)
    end},
  cb)
end

local function test_upgrade(version, expected_status, test, asserts)
  local options = createOptions(path.join(TEST_DIR, testexe), version)
  setupExe(TEST_DIR, testexe, '0777', function(err)
    asserts.ok(not err, err)
    upgrade.attempt(options, function(err, status)
      asserts.ok(not err)
      asserts.ok(status == expected_status)
      test.done()
    end)
  end)
end

exports['test_virgo_upgrade_1'] = function(test, asserts)
  test_upgrade('0.2.0-24', upgrade.UPGRADE_EQUAL, test, asserts)
end

exports['test_virgo_upgrade_2'] = function(test, asserts)
  test_upgrade('0.2.0-23', upgrade.UPGRADE_PERFORM, test, asserts)
end

exports['test_virgo_upgrade_3'] = function(test, asserts)
  test_upgrade('0.2.0-25', upgrade.UPGRADE_DOWNGRADE, test, asserts)
end

return exports
