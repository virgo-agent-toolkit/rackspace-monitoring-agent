--[[
Copyright 2014 Rackspace

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
local HostInfo = require('./base').HostInfo

local string = require('string')
local fmt = require('string').format
local table = require('table')
local os = require('os')
local spawn = require('childprocess').spawn

--[[ Listening Variables ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function table_slice(values, i1, i2)
  local res = {}
  local n = #values
  -- default values for range
  i1 = i1 or 1
  i2 = i2 or n
  if i2 < 0 then
    i2 = n + i2 + 1
  elseif i2 > n then
    i2 = n
  end
  if i1 < 1 or i1 > n then
    return {}
  end
  local k = 1
  for i = i1,i2 do
    res[k] = values[i]
    k = k + 1
  end
  return res
end

function Info:run(callback)
  if os.type() ~= 'Linux' then
    self._error = 'Unsupported OS for LISTENING implementation'
    callback()
    return
  end

  local child = spawn('netstat', {'-tlpen'}, {})
  local data = ''

  child.stdout:on('data', function(chunk)
    data = data .. chunk
  end)

  child:on('exit', function(exit_code)
    if exit_code ~= 0 then
      self._error = fmt("netstat exited with a %d exit_code", exitcode)
      callback()
      return
    end
  end)

  child.stdout:on('end', function()
    local line
    local count = 0
    for line in data:gmatch("[^\r\n]+") do
      -- skip first two header lines
      count = count + 1
      if count < 3 then goto continue end

      -- parse line into columns
      local i = 0;
      local things = {}
      for thing in line:gmatch("%S+") do
        i = i + 1
        things[i] = thing;
      end
      local proto = things[1]
      local recv = things[2]
      local send = things[3]
      local laddress = things[4]
      local faddress = things[5]
      local state = things[6]
      local user = things[7]
      local inode = things[8]
      local pid_name = things[9]

      -- split local address to ip and port (handle v4 and v6)
      local x = 0
      local parts = {}
      for part in laddress:gmatch("([^:]*)") do
        if #part > 0 then
          x = x + 1
          parts[x] = part
        end
      end
      local ip = table.concat(table_slice(parts, 1, -2), ":")
      if #ip == 0 then ip = "::" end

      -- split prog/pid into parts
      local y = 0
      local prog_parts = {}
      for prog_part in pid_name:gmatch("([^/]*)") do
        if #prog_part > 0 then
          y = y + 1
          prog_parts[x] = prog_part
        end
      end

      -- build metric
      local obj = {}
      obj['protocol'] = proto
      obj['ip'] = ip
      obj['port'] = parts[#parts]
      obj['pid'] = prog_parts[1]
      obj['process'] = prog_parts[2]
      obj['path'] = pid_name
      table.insert(self._params, obj)
      ::continue::
    end
    callback()
  end)

  child:on('error', function(err)
    self._error = err
    callback()
  end)
end

function Info:getType()
  return 'LISTENING'
end

return Info
