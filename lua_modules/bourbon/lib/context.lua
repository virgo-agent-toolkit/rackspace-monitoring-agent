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
      return ok, ret_or_err
    else
      self.failed = self.failed + 1

      local info = {}
      info.ret = ret_or_err
      -- TODO: strip traceback level
      info.traceback = debug.traceback()
      table.insert(self.errors, info)
      test.done()
      error(ret_or_err)
    end
  end

  local newgt = {}
  setmetatable(newgt, {__index = _G})
  local asserts = require('./asserts')
  asserts.assert = bourbon_assert

  setfenv(func, newgt)
  ok, ret_or_err = pcall(func, test, asserts)
  return ret_or_err
end

function Context.prototype:add_stats(c)
  -- TODO: use forloop
  self.checked = self.checked + c.checked
  self.failed = self.failed + c.failed
  self.passed = self.passed + c.passed
end

function Context.prototype:print_summary()
  print("checked: " .. self.checked .. " failed: " .. self.failed .. " passed: " .. self.passed)
  self:print_errors()
end

function Context.prototype:print_errors()
  self:dump_errors(print)
end

function Context.prototype:dump_errors(func)
  for i, v in ipairs(self.errors) do
    func("Error #" .. i)
    func("\t" .. v.ret)
    func("\t" .. v.traceback)
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
