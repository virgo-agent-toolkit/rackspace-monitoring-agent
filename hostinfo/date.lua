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

--[[ Date ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end
function Info:_run(callback)
  local it = os.date('%H:%M:%S %Y %m %d %Z'):gmatch('%S+')
  local fields = {}
  fields.time = it()
  fields.date = {}
  fields.date.year = it()
  fields.date.month = it()
  fields.date.day = it()
  fields.timezone = it()
  table.insert(self._params, fields)
  callback()
end

function Info:getType()
  return 'DATE'
end

return Info

