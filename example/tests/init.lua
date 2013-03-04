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

_G.TEST_DIR = path.join(process.cwd(), 'tests', 'tmp')

local TESTS_TO_RUN = {
  './virgo',
}

local function runit(modname, callback)
  local status, mod = pcall(require, modname)
  if status ~= true then
    process.stdout:write(fmt('Error loading test module [%s]: %s\n\n', modname, tostring(mod)))
    callback(mod)
    return
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

local function rmdir(dir)
  local success, err = pcall(fs.readdirSync, dir)
  if not success then
    if err.code == 'ENOENT' then
      return
    end
    error(err)
  end
  for _, file in ipairs(err) do
    local p = path.join(dir, file)
    local info = fs.statSync(p)
    if info.is_file then
      fs.unlinkSync(p)
    else
      rmdir(p)
    end
  end
  fs.rmdirSync(dir)
end

exports.run = function()
  -- set the exitCode to error in case we trigger some
  -- bug that causes us to exit the loop early
  process.exitCode = 1
  rmdir(TEST_DIR)
  fs.mkdirSync(TEST_DIR, "0755")
  async.forEachSeries(TESTS_TO_RUN, runit, function(err)
    rmdir(TEST_DIR)

    if err then
      p(err)
      debugm.traceback(err)
      return process.exit(1)
    end

    process.exitCode = 0
  end)
end

return exports
