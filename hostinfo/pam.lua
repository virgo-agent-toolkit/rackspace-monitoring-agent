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
--]]
local HostInfo = require('./base').HostInfo

local table = require('table')
local los = require('los')
local readCast = require('./misc').readCast
local async = require('async')
local fs = require('fs')
local path = require('path')

--[[ Pluggable auth modules ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:run(callback)
  if los.type() ~= 'linux' then
    self._error = 'Unsupported OS for pluggable auth module definitions'
    return callback()
  end

  local function casterFunc(iter, obj, line)
    local keywords = {
      password = true,
      auth = true,
      account = true,
      session = true
    }
    local module_interface, control_flags, module_name, module_arguments, soStart, soEnd
    if line:find('%\t') then
      iter = line:gmatch('%\t')
    end

    module_interface = iter()
    if keywords[module_interface] then
      soStart, soEnd = line:find('%.so')
      -- sometimes the pam files have many control flags
      if line:find('%]') then
        control_flags = line:sub(line:find('%[')+1, line:find('%]')-1)
        module_name = line:sub(line:find('%]')+2, soEnd)
      else
        control_flags = iter()
        module_name = iter()
      end
      -- They also like to have variable numbers of module args
      if line:len() ~= soEnd and soEnd ~= nil then
        module_arguments = line:sub(soEnd+2, line:len())
      else
        module_arguments = ''
      end
      table.insert(obj, {
        module_interface = module_interface,
        control_flags = control_flags,
        module_name = module_name,
        module_arguments = module_arguments
      })
    end
  end

  local pamPath = '/etc/pam.d'
  local filesList = fs.readdirSync(pamPath)
  async.forEachLimit(filesList, 5, function(file, cb)
    readCast(path.join(pamPath, file), self._error, self._params, casterFunc, cb)
  end, callback)
end

function Info:getType()
  return 'PAM'
end

return Info
