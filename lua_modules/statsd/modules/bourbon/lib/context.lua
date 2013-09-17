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
local Object = require('core').Object
local table = require('table')

local Context = Object:extend()

function Context:run(func, test)
  local bourbon_assert = function(assertion, msg)
    local ok, ret_or_err = pcall(assert, assertion, msg)
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

  -- if test threw an exception without catching it we end up here
  if ret_or_err then
    local info = {}
    info.ret = ret_or_err

    self.failed = self.failed + 1
    info.traceback = debug.traceback()
    table.insert(self.errors, info)
    test.done()
  end

  return ret_or_err
end

function Context:add_stats(c)
  -- TODO: use forloop
  self.checked = self.checked + c.checked
  self.failed = self.failed + c.failed
  self.passed = self.passed + c.passed
  self.skipped = self.skipped + c.skipped
end

function Context:print_summary()
  print("checked: " .. self.checked .. " failed: " .. self.failed .. " skipped: " .. self.skipped .. " passed: " .. self.passed)
  self:print_errors()
end

function Context:print_errors()
  self:dump_errors(print)
end

function Context:dump_errors(func)
  for i, v in ipairs(self.errors) do
    func("Error #" .. i)

    if type(v.ret) == 'string' then
      func("\t" .. v.ret)
    else
      func("\t" .. utils.dump(v.ret))
    end

    func("\t" .. v.traceback)
  end
end

function Context:initialize()
  self.checked = 0
  self.failed = 0
  self.skipped = 0
  self.passed = 0
  self.errors = {}
end

return Context
