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
  tb._runenr = runner
  tb.done = function()
    stats:add_stats(runner.context)
    callback()
  end
  setmetatable(tb, {__index=TestBaton.prototype})
  return tb
end


local run_test = function(runner, stats, callback)
  process.stdout:write(fmt("Running %s\n", runner.name))
  local test_baton = TestBaton.new(runner, stats, function(err)
    process.stdout:write(fmt("Finished running %s\n", runner.name))
    callback(err)
  end)
  runner.context:run(runner.func, test_baton)
end

local run = function(mods)
  local runners = {}
  local ops = {}
  local stats = context.new()

  for k, v in pairs(get_tests(mods)) do
    if not is_control_function(k) then
      table.insert(runners, 1, { name = k, func = v, context = context.new() })
    end
  end

  local function setup(callback)
    local test_baton = TestBaton.new({context = context.new()}, stats, callback)
    mods.setup(test_baton)
  end

  local function teardown(callback)
    local test_baton = TestBaton.new({context = context.new()}, stats, callback)
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
    fun(callback)
  end, function(err)
    if err then
      process.stdout:write(err .. '\n')
      return
    end
    process.stdout:write('Totals' .. '\n')
    stats:print_summary()
  end)
end

return run
