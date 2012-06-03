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

local bourbon = require('bourbon')
local async = require('async')
local fmt = require('string').format
local debugm = require('debug')
local path = require('path')
local fs = require('fs')

local exports = {}

local failed = 0

local tmp_dir = path.join('tests', 'tmp')
local function remove_tmp(callback)
  fs.readdir(tmp_dir, function(err, files)
    if (files ~= nil) then
      for i, v in ipairs(files) do
        fs.unlinkSync(path.join(tmp_dir, v))
      end
    end
    fs.rmdir(tmp_dir, callback)
  end)
end

local TESTS_TO_RUN = {
  path.join(__dirname, './tls'),
  path.join(__dirname, './agent-protocol'),
  path.join(__dirname, './crypto'),
  path.join(__dirname, './check'),
  path.join(__dirname, './schedule')
}

exports.run = function()
  -- set the exitCode to error in case we trigger some
  -- bug that causes us to exit the loop early
  process.exitCode = 1

  async.waterfall({
    function(callback)
      fs.mkdir(tmp_dir, '0755', function(err)
        callback(err)
      end)
    end,

    function(callback)
      bourbon.runner.runTestFiles(TESTS_TO_RUN, {}, callback)
    end
  },

  function(err, failed)
    remove_tmp(function()
      if err then
        process.exit(1)
      end

      process.exit(failed)
    end)
  end)
end

return exports
