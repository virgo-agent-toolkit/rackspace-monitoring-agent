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
local table = require('table')

local split = require('monitoring/default/util/misc').split

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

local TESTS_TO_RUN = {'./collector', './tls', './agent-protocol', './crypto', './misc', './check', './fs', './schedule'}

if process.env['TEST_FILES'] then
  TESTS_TO_RUN = split(process.env['TEST_FILES'])
end

local function runit(modname, callback)
  local status, mod = pcall(require, modname)
  if status ~= true then
    process.stdout:write(fmt('Error loading test module [%s]: %s\n\n', modname, tostring(mod)))
    callback(mod)
  end
  process.stdout:write(fmt('Executing test module [%s]\n\n', modname))
  bourbon.run(nil, mod, function(err, stats)
    process.stdout:write('\n')

    if stats then
      failed = failed + stats.failed
    end

    callback(err)
  end)
end

exports.run = function()
  -- set the exitCode to error in case we trigger some
  -- bug that causes us to exit the loop early
  process.exitCode = 1

  fs.mkdir(tmp_dir, "0755", function()
    async.forEachSeries(TESTS_TO_RUN, runit, function(err)
      if err then
        p(err)
        debugm.traceback(err)
        remove_tmp(function()
          process.exit(1)
        end)
      end

      process.exitCode = 0
      remove_tmp(function()
        process.exit(failed)
      end)
    end)
  end)
end

return exports
