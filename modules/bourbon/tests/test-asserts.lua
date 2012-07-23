#!/usr/bin/env luvit

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

exports = {}

exports['test_asserts_ok'] = function(test, asserts)
  asserts.ok(true)
  test.done()
end

exports['test_asserts_equals'] = function(test, asserts)
  asserts.equals(1, 1)
  test.done()
end

exports['test_asserts_dequals'] = function(test, asserts)
  asserts.dequals({1,2,3, foo = 'foo', bar = { 'baz' }}, {bar = { 'baz' }, 1,2,3, foo = 'foo'})
  test.done()
end

exports['test_asserts_nil'] = function(test, asserts)
  asserts.is_nil(nil)
  test.done()
end

exports['test_asserts_not_nil'] = function(test, asserts)
  asserts.not_nil(1)
  asserts.throws(error, "foobar")
  test.done()
end

--[[exports['test_asserts_table'] = function(test, asserts)
  asserts.is_table({})
  asserts.is_table({1,2,3})
  asserts.is_table({a=1,b=3})
  asserts.is_table({a=1,0,2,3,b=3})
  _not(asserts.is_table, 1)
  _not(asserts.is_table, false)
  _not(asserts.is_table, true)
  _not(asserts.is_table, 'a')
  test.done()
end]]--

--[[
exports['test_asserts_array'] = function(test, asserts)
  asserts.is_table({})
  asserts.is_table({1,2,3})
  asserts.is_table({a=1,b=3})
  asserts.is_table({a=1,0,2,3,b=3})
  asserts.is_table(1)
  asserts.is_table(false)
  asserts.is_table(true)
  asserts.is_table('a')
  test.done()
end
]]--

return exports
