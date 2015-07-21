--[[
Copyright 2015 Rackspace

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
]]--
local table = require('table')
local los = require('los')
local fs = require('fs')
local string = require('string')

--[[ Check fstab ]]--
local HostInfo = require('./base').HostInfo
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:run(callback)
  local fstab = {}
  local types = {'file_system', 'mount_point', 'type', 'options', 'pass' }

  if los.type() ~= 'linux' then
    self._error = 'Unsupported OS for file permissions'
    return callback()
  end

  fs.exists('/etc/fstab', function(err, file)
    if err then
      self._error = string.format('fs.exists in fstab.lua erred: %s', err)
      return callback()
    end
    if file then
      fs.readFile('/etc/fstab', function(err, data)
        if err then
          self._error = string.format('fs.readline in fstab.lua erred: %s', err)
          return callback()
        end

        for line in data:gmatch("[^\r\n]+") do
          local iscomment = string.match(line, '^#')
          local isblank = string.len(line:gsub("%s+", "")) <= 0

          if not iscomment and not isblank then
            local obj = {}

            -- split the line and assign key vals
            local iter = line:gmatch("%S+")
            for i = 1, #types do
              obj[types[i]] = iter()
            end

            table.insert(fstab, obj)
          end
        end
        -- fstab usually only has one line, flatten it
        if #fstab == 1 then
          fstab = fstab[1]
        end

        table.insert(self._params, {fstab=fstab})
        return callback()
      end)

    else
      self._error = 'fstab not found'
      return callback()
    end

  end)

end


function Info:getType()
  return 'FSTAB'
end

return Info
