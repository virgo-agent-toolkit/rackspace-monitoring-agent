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

local math = require('math')
local timer = require('timer')
local table = require('table')
local string = require('string')

--[[
Split an address.

address - Address in ip:port format.
return [ip, port]
]]--
function splitAddress(address)
  -- TODO: Split on last colon (ipv6)
  local start, result
  start, _ = address:find(':')

  if not start then
    return null
  end

  result = {}
  result[1] = address:sub(0, start - 1)
  result[2] = tonumber(address:sub(start + 1))
  return result
end

-- See Also: http://lua-users.org/wiki/SplitJoin
function split(str, pattern)
  pattern = pattern or "[^%s]+"
  if pattern:len() == 0 then pattern = "[^%s]+" end
  local parts = {__index = table.insert}
  setmetatable(parts, parts)
  str:gsub(pattern, parts)
  setmetatable(parts, nil)
  parts.__index = nil
  return parts
end

function tablePrint(tt, indent, done)
  done = done or {}
  indent = indent or 0
  if type(tt) == "table" then
    local sb = {}
    for key, value in pairs (tt) do
      table.insert(sb, string.rep (" ", indent)) -- indent it
      if type (value) == "table" and not done [value] then
        done [value] = true
        table.insert(sb, "{\n");
        table.insert(sb, tablePrint (value, indent + 2, done))
        table.insert(sb, string.rep (" ", indent)) -- indent it
        table.insert(sb, "}\n");
      elseif "number" == type(key) then
        table.insert(sb, string.format("\"%s\"\n", tostring(value)))
      else
        table.insert(sb, string.format(
        "%s = \"%s\"\n", tostring (key), tostring(value)))
      end
    end
    return table.concat(sb)
  else
    return tt .. "\n"
  end
end

function toString(tbl)
  if  "nil"       == type( tbl ) then
    return tostring(nil)
  elseif  "table" == type( tbl ) then
    return tablePrint(tbl)
  elseif  "string" == type( tbl ) then
    return tbl
  else
    return tostring(tbl)
  end
end

function createJitterTimeout(n, jitter)
  return n + (jitter * math.random())
end

-- merge tables
function merge(...)
  local args = {...}
  local first = args[1]

  for i, _ in ipairs(args) do
    if i ~= 1 then
      local t = args[i]
      for k, _ in pairs(t) do
        first[k] = t[k]
      end
    end
  end

  return first
end

--[[ Exports ]]--
local exports = {}
exports.createJitterTimeout = createJitterTimeout
exports.merge = merge
exports.splitAddress = splitAddress
exports.split = split
exports.toString = toString
return exports
