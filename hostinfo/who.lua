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

local sigarCtx = require('/sigar').ctx
local sigarutil = require('/base/util/sigar')

local table = require('table')

--[[ Who is logged In ]]--
local WhoInfo = HostInfo:extend()
function WhoInfo:initialize()
  HostInfo.initialize(self)
  local who = sigarCtx:who()
  local fields = {
    'user',
    'device',
    'time',
    'host'
  }

  for i=1, #who do
    local obj = {}
    for _, v in pairs(fields) do
      obj[v] = who[i][v]
    end
    table.insert(self._params, obj)
  end
end

function WhoInfo:getType()
  return 'WHO'
end

return WhoInfo
