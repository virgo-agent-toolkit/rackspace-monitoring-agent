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

local async = require 'async'
local table = require 'table'
local string = require 'string'
local math = require 'math'

local fmt = string.format

local context = require './context'

function is_test_key(k)
  return type(k) == "string" and k:match("_*test.*")
end

local function is_control_function(name)
  return name == 'setup' or
         name == 'teardown' or
         name == 'ssetup' or
         name == 'steardown'
end

local function get_tests(mod)
  local ts = {}
  if not mod then return ts end
  for k,v in pairs(mod) do
    if is_test_key(k) and type(v) == "function" then
      ts[k] = v
    end
  end
  ts.setup = rawget(mod, "setup")
  ts.teardown = rawget(mod, "teardown")
  ts.ssetup = rawget(mod, "suite_setup")
  ts.steardown = rawget(mod, "suite_teardown")
  return ts
end

local TestBaton = {}
TestBaton.prototype = {}

function TestBaton.new(runner, stats, callback)
  local tb = {}
  tb._callback = callback
  tb._stats = stats
  tb._runner = runner
  tb.done = function()
    stats:add_stats(runner.context)
    callback()
  end
  tb.skip = function(reason)
    runner.context.skipped = runner.context.skipped + 1
    stats:add_stats(runner.context)
    callback(nil, true, reason)
  end
  setmetatable(tb, {__index=TestBaton.prototype})
  return tb
end


local run_test = function(runner, stats, callback)
  process.stdout:write(fmt("  Running %s", runner.name))
  local test_baton = TestBaton.new(runner, stats, function(err, skipped, skipReason)
    if skipped then
      if skipReason ~= nil then
        process.stdout:write(" SKIPPED (" .. skipReason .. ")\n")
      else
        process.stdout:write(" SKIPPED\n")
      end
    else
      process.stdout:write(" DONE\n")
    end

    runner.context:dump_errors(function(line)
      process.stdout:write(line)
    end)

    callback(err)
  end)
  runner.context:run(runner.func, test_baton)
end

local run = function(options, mods, callback)
  if not mods then return end
  local runners = {}
  local ops = {}
  local stats = context:new()

  options = options or {
    print_summary = true,
    verbose = true
  }

  for k, v in pairs(get_tests(mods)) do
    if not is_control_function(k) then
      table.insert(runners, 1, { name = k, func = v, context = context:new() })
    end
  end

  local function setup(callback)
    local test_baton = TestBaton.new({context = context:new()}, stats, callback)
    mods.setup(test_baton)
  end

  local function teardown(callback)
    local test_baton = TestBaton.new({context = context:new()}, stats, callback)
    mods.teardown(test_baton)
  end

  local function run_tests(callback)
    async.forEachSeries(runners, function(runner, callback)
      run_test(runner, stats, callback)
    end, callback)
  end

  if mods.setup then
    table.insert(ops, setup)
  end

  table.insert(ops, run_tests)

  if mods.teardown then
    table.insert(ops, teardown)
  end

  async.forEachSeries(ops, function(fun, callback)
    local status, err = pcall(fun, callback)
    if status ~= true then
      callback(err, stats)
    end
  end, function(err)
    if err then
      process.stdout:write(err .. '\n')
      return
    end
    if options.print_summary then
      process.stdout:write('\nTotals' .. '\n')
      stats:print_summary()
      process.stdout:write('---------------------------------------')
    end

    if callback then callback(nil, stats) end
  end)
end

return run
