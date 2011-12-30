local async = require './init.lua'
local table = require 'table'
local string = require 'string'
local math = require 'math'

local fmt = string.format

local checked = 0

local asserts = {}
asserts.equal = function(a, b)
  checked = checked + 1
  assert(a == b)
end
asserts.ok = function(a)
  checked = checked + 1
  assert(a)
end
asserts.equals = function(a, b)
  checked = checked + 1
  assert(a == b)
end
asserts.array_equals = function(a, b)
  checked = checked + 1
  assert(#a == #b)
  for k=1, #a do
    assert(a[k] == b[k])
  end
end
asserts.not_nil = function(a)
  checked = checked + 1
  assert(a ~= nil)
end

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

local run_test = function(runner, callback)
  p (fmt("Running %s", runner.name))

  local test_baton = {}
  test_baton.done = function()
    callback()
  end
  runner.func(test_baton, asserts)
end

local run = function(mods)
  local runners = {}

  for k, v in pairs(get_tests(mods)) do
    table.insert(runners, 1, { name = k, func = v })
  end

  async.forEachSeries(runners, function(runner, callback)
    run_test(runner, callback)
  end, function(err)
    if err then
      p(err)
      return
    end
    p(fmt("Executed %s asserts", checked))
  end)
end

-- Exports

local exports = {}
exports.asserts = asserts
exports.run = run
return exports
