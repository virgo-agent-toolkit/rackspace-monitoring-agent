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

local fs = require('fs');
local string = require('string')
local table = require('table')
local os = require('os')

--[[ Login ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:run(callback)
  
  if os.type() ~= 'Linux' then
    self._error = 'Unsupported OS for Login Definitions'
    callback()
    return
  end
  
  local obj = {}
  local filename = "/etc/login.defs"
    
  obj['login.defs'] = {}
  
  -- open /etc/login.defs
  fs.readFile(filename, function (err, data)
    if (err) then
      return
    end

    -- split and assign key/values
    for line in data:gmatch("[^\r\n]+") do
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
  end)
end

function Info:getType()
  return 'LOGIN'
end

return Info