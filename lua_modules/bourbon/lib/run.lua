local async = require 'async'
local table = require 'table'
local string = require 'string'
local math = require 'math'

local fmt = string.format

local context = require './context'

function is_test_key(k)
  return type(k) == "string" and k:match("_*test.*")
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

local run_test = function(runner, stats, callback)
  p (fmt("Running %s", runner.name))

  local test_baton = {}
  test_baton.done = function()
    stats:add_stats(runner.context)
    runner.context:print_summary()
    callback()
  end
  runner.context:run(runner.func, test_baton)
end

local run = function(mods)
  local runners = {}
  local stats = context.new()

  for k, v in pairs(get_tests(mods)) do
    table.insert(runners, 1, { name = k, func = v, context = context.new() })
  end

  async.forEachSeries(runners, function(runner, callback)
    run_test(runner, stats, callback)
  end, function(err)
    if err then
      p(err)
      return
    end
    p(fmt("Totals"))
    stats:print_summary()
  end)
end

return run
