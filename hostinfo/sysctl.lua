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

local fmt = require('string').format
local table = require('table')
local los = require('los')

--[[ Sysctl Variables ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:run(callback)
  if los.type() ~= 'linux' then
    self._error = 'Unsupported OS for sysctl'
    return callback()
  end

  local function execCb(err, exitcode, data, stderr_data)
    if exitcode ~= 0 then
      self._error = fmt("sysctl exited with a %d exit_code", exitcode)
      return callback()
    end
    for line in data:gmatch("[^\r\n]+") do
      line = line:gsub("^%s*(.-)%s*$", "%1")
      local _, _, key, value = line:find("([^=^%s]+)%s*=%s*([^=]*)")
      if key and #key > 0 then
        table.insert(self._params, {[key] = value})
      end
    end
    return callback()
  end

  self._util.execFileToBuffers('which', {'sysctl'}, {}, function(err, exitcode, data, stderr)
    if exitcode ~= 0 then
      self._error = fmt("sysctl exited with a %d exit_code", exitcode)
      return callback()
    end
    -- Remove /n at the end of data returned from which and call
    return self._util.execFileToBuffers(self._util.trimAll(data), {'-A'}, {}, execCb)
  end)

end

function Info:getType()
  return 'SYSCTL'
end

return Info
