local utils = require('utils')
local debug = require('debug')
local table = require('table')

local Context = {}
Context.prototype = {}

function Context.prototype:run(func, test)
  local bourbon_assert = function(assertion)
    local ok, ret_or_err = pcall(assert, assertion)

    if ok then
      self.passed = self.passed + 1
      return ok
    else
      self.failed = self.failed + 1

      local info = {}
      info.ret = ret_or_err
      -- TODO: strip traceback level
      info.traceback = debug.traceback()
      table.insert(self.errors, info)

      return ok
    end
  end

  local newgt = {}
  setmetatable(newgt, {__index = _G})
  local asserts = require('./asserts')
  asserts.assert = bourbon_assert

  setfenv(func, newgt)
  ok, ret_or_err = pcall(func, test, asserts)
  if ok then
    return ret_or_err
  else
    error(ret_or_err)
  end
end

function Context.prototype:add_stats(c)
  -- TODO: use forloop
  self.checked = self.checked + c.checked
  self.failed = self.failed + c.failed
  self.passed = self.passed + c.passed
end

function Context.prototype:print_summary()
  print("checked: " .. self.checked .. " failed: " .. self.failed .. " passed: " .. self.passed)
  for i, v in ipairs(self.errors) do
    print("Error #" .. i)
    print("\t" .. v.ret)
    print("\t" .. v.traceback)
  end
end

utils.inherits(Context, Context.prototype)
Context.new = function()
  local t = Context.new_obj()
  t.checked = 0
  t.failed = 0
  t.passed = 0
  t.errors = {}
  return t
end

return Context
