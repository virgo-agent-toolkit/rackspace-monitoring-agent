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
  bourbon_assert(a == b, 'a')
end

asserts.ok = function(a, msg)
  local msg = msg or tostring(a) .. ' != true'
  asserts.assert(a, msg)
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
  asserts.assert(#a == #b)
  for k=1, #a do
    asserts.assert(a[k] == b[k])
  end
end

asserts.not_nil = function(a)
  asserts.assert(a ~= nil)
end

asserts.is_nil = function(a)
  asserts.assert(a == nil)
end

asserts.is_number = function(a)
  asserts.assert(type(a) == 'number')
end

asserts.is_boolean = function(a)
  asserts.assert(type(a) == 'boolean')
end

asserts.is_string = function(a)
  asserts.assert(type(a) == 'string')
end

asserts.is_table = function(a)
  asserts.assert(type(a) == 'table')
end

asserts.is_array = function(a)
  asserts.assert(type(a) == 'table')
  for k, v in pairs(a) do
    asserts.assert(false)
  end
end

asserts.is_hash = function(a)
  asserts.assert(type(a) == 'table')
  for k, v in ipairs(a) do
    asserts.assert(false)
  end
end

asserts.throws = function(...)
  local s, e = pcall(...)
  asserts.assert(not s)
  asserts.assert(e)
end


return asserts
