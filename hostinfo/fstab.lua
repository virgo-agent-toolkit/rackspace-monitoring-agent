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

--[[ Check fstab ]]--
local HostInfoFs = require('./base').HostInfoFs
local Info = HostInfoFs:extend()

function Info:initialize()
  HostInfoFs.initialize(self, '/etc/fstab')
end

function Info:_transform(line, cb)
  local iter = line:gmatch("%S+")
  local types = {'file_system', 'mount_point', 'type', 'options', 'pass' }
  for i = 1, #types do
    self.obj[types[i]] = iter()
  end
  cb()
end

function Info:_execute(callback)
  self:readCast(callback)
end

function Info:getPlatforms()
  return {'linux'}
end

function Info:getType()
  return 'FSTAB'
end


return Info
