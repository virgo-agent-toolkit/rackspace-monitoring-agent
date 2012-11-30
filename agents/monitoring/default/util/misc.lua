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
local fs = require('fs')
local logging = require('logging')

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

function writePid(pidFile, callback)
  if pidFile then
    logging.info('Writing PID to ' .. pidFile)
    fs.writeFile(pidFile, tostring(process.pid), function(err)
      if err then
        logging.error('Failed writing PID')
      else
        logging.info('Successfully wrote ' .. pidFile)
      end
      callback(err)
    end)
  else
    callback()
  end
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
        table.insert(sb, key .. " = {\n");
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

function calcJitter(n, jitter)
  return math.floor(n + (jitter * math.random()))
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

-- Return true if an item is in a table, false otherwise.
-- f - function which is called on every item and should return true if the item
-- matches, false otherwise
-- t - table
function tableContains(f, t)
  for _, v in ipairs(t) do
    if f(v) then
      return true
    end
  end

  return false
end

function trim(s)
  return s:find'^%s*$' and '' or s:match'^%s*(.*%S)'
end

-- Return start index of last occurance of a pattern in a string
function lastIndexOf(str, pat)
  local startIndex, endIndex
  local lastIndex = -1
  local found = false

  while 1 do
    startIndex, endIndex = string.find(str, pat, lastIndex + 1)
    if not startIndex then
      break
    else
      lastIndex = startIndex
    end
  end

  if lastIndex == -1 then
    return nil
  end

  return lastIndex
end

function fireOnce(callback)
  local called = false

  return function(...)
    if not called then
      called = true
      callback(unpack({...}))
    end
  end
end

function nCallbacks(callback, count)
  local n, triggered = 0, false
  return function()
    if triggered then
      return
    end
    n = n + 1
    if count == n then
      triggered = true
      callback()
    end
  end
end

function isNaN(a)
  return tonumber(a) == nil
end

--[[
Compare version strings.
Returns: -1, 0, or 1, if a < b, a == b, or a > b
]]
function compareVersions(a, b)
  local aParts, bParts, pattern, aItem, bItem

  if a == b then
    return 0
  end

  if not a then
    return -1
  end

  if not b then
    return 1
  end

  pattern = '[0-9a-zA-Z]+'
  aParts = split(a, pattern)
  bParts = split(b, pattern)

  aItem = table.remove(aParts, 1)
  bItem = table.remove(bParts, 1)

  while aItem and bItem do
    if not isNaN(aItem) and not isNaN(bItem) then
      if aItem < bItem then
        return -1
      end
      if aItem > bItem then
        return 1
      end
    else
      if isNaN(aItem) then
        return -1
      end
      if isNaN(bItem) then
        return 1
      end
    end
    aItem = table.remove(aParts, 1)
    bItem = table.remove(bParts, 1)
  end

  if aItem then
    return 1
  elseif bItem then
    return -1
  end

  return 0
end


function propagateEvents(fromClass, toClass, eventNames)
  for _, v in pairs(eventNames) do
    fromClass:on(v, function(...)
      toClass:emit(v, ...)
    end)
  end
end


--[[ Exports ]]--
local exports = {}
exports.calcJitter = calcJitter
exports.merge = merge
exports.splitAddress = splitAddress
exports.split = split
exports.toString = toString
exports.tableContains = tableContains
exports.trim = trim
exports.writePid = writePid
exports.lastIndexOf = lastIndexOf
exports.fireOnce = fireOnce
exports.nCallbacks = nCallbacks
exports.compareVersions = compareVersions
exports.propagateEvents = propagateEvents
return exports
