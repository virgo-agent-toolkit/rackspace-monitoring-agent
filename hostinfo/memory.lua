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

--[[ MemoryInfo ]]--
local MemoryInfo = HostInfo:extend()
function MemoryInfo:initialize()
  HostInfo.initialize(self)
  local swapinfo = sigarCtx:swap()
  local data = sigarCtx:mem()
  local data_fields = {
    'actual_free',
    'actual_used',
    'free',
    'free_percent',
    'ram',
    'total',
    'used',
    'used_percent'
  }
  local swap_metrics = {
    'total',
    'used',
    'free',
    'page_in',
    'page_out'
  }
  if data then
    for _, v in pairs(data_fields) do
      self._params[v] = data[v]
    end
  end
  if swapinfo then
    for _, k in pairs(swap_metrics) do
      self._params['swap_' .. k] = swapinfo[k]
    end
  end
end

function MemoryInfo:getType()
  return 'MEMORY'
end

return MemoryInfo
