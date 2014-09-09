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

local io = require('io')
local string = require('string')
local table = require('table')

--[[ Login ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:run(callback)
  local obj = {}
  local file = io.lines('/etc/login.defs')
  local append = table.insert
  
  obj['login.defs'] = {}
  
  -- loop through lines in file
  for line in file do
    local iscomment = string.match(line, '^#')
    local isblank = string.len(line:gsub("%s+", "")) <= 0
    
    -- find defs
    if not iscomment and not isblank then
      local items = {}
      local i = 0
      
      -- split and assign key/values
      for item in line:gmatch("%S+") do
        i = i + 1
        items[i] = item;
      end
      
      local key = items[1]
      local value = items[2]
      
      -- add def
      obj['login.defs'][key] = value
    end
  end
  
  table.insert(self._params, obj)
  callback()
end

function Info:getType()
  return 'LOGIN'
end

return Info