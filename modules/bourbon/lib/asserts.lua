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

local asserts = {}

asserts.assert = assert

asserts.equal = function(a, b, msg)
  local msg = msg or tostring(a) .. ' != ' .. tostring(b)
  asserts.assert(a == b, msg)
end

asserts.ok = function(a, msg)
  local msg = msg or tostring(a) .. ' != true'
  asserts.assert(a, msg)
end

asserts.not_ok = function(a, msg)
  local msg = msg or tostring(a) .. ' != false'
  asserts.assert(not a, msg)
end


asserts.equals = function(a, b, msg)
  local msg = msg or tostring(a) .. ' != ' .. tostring(b)
  asserts.assert(a == b, msg)
end

asserts.dequals = function(a, b)
  if type(a) == 'table' and type(b) == 'table' then
    asserts.array_equals(a, b)
    for k, v in pairs(a) do
      asserts.dequals(v, b[k])
    end
    for k, v in pairs(b) do
      asserts.dequals(v, a[k])
    end
  else
    asserts.equals(a, b)
  end
end

asserts.array_equals = function(a, b)
  local msg
  asserts.assert(#a == #b, '#a (' .. #a .. ') != #b - (' .. #b .. ')')
  for k=1, #a do
    msg = tostring(a[k]) .. ' != ' .. tostring(b[k])
    asserts.assert(a[k] == b[k], msg)
  end
end

asserts.not_nil = function(a, msg)
  local msg = msg or tostring(a) .. ' == nil'
  asserts.assert(a ~= nil, msg)
end

asserts.is_nil = function(a, msg)
  local msg = msg or tostring(a) .. ' != nil'
  asserts.assert(a == nil, msg)
end

asserts.is_number = function(a, msg)
  local msg = msg or tostring(a) .. ' is not a number'
  asserts.assert(type(a) == 'number', msg)
end

asserts.is_boolean = function(a, msg)
  local msg = msg or tostring(a) .. ' is not a boolean'
  asserts.assert(type(a) == 'boolean', msg)
end

asserts.is_string = function(a, msg)
  local msg = msg or tostring(a) .. ' is not a string'
  asserts.assert(type(a) == 'string', msg)
end

asserts.is_table = function(a, msg)
  local msg = msg or tostring(a) .. ' is not a table'
  asserts.assert(type(a) == 'table', msg)
end

asserts.is_array = function(a, msg)
  local msg = msg or tostring(a) .. ' is not an array'
  asserts.assert(type(a) == 'table', msg)
  for k, v in pairs(a) do
    asserts.assert(false)
  end
end

asserts.is_hash = function(a, msg)
  local msg = msg or tostring(a) .. ' is not a hash'
  asserts.assert(type(a) == 'table', msg)
  for k, v in ipairs(a) do
    asserts.assert(false)
  end
end

asserts.throws = function(...)
  local s, e = pcall(...)
  asserts.assert(not s)
  asserts.ok(e, 'Function didn\'t throw')
end

asserts.doesnt_throw = function(...)
  local s, e = pcall(...)
  asserts.ok(not e, 'Function thrown an error')
end

return asserts
