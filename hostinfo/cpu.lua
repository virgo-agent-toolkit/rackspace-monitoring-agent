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
local sigar = require('sigar')
local table = require('table')

--[[ Info ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
  local ctx = sigar:new()
  local cpus = ctx:cpus()
  for i=1, #cpus do
    local obj = {}
    local info = cpus[i]:info()
    local data = cpus[i]:data()
    local name = 'cpu.' .. i - 1
    local data_fields = {
      'idle',
      'irq',
      'nice',
      'soft_irq',
      'stolen',
      'sys',
      'total',
      'user',
      'wait'
    }
    local info_fields = {
      'mhz',
      'model',
      'total_cores',
      'total_sockets',
      'vendor'
    }

    for _, v in pairs(data_fields) do
      obj[v] = data[v]
    end
    for _, v in pairs(info_fields) do
      obj[v] = info[v]
    end

    obj['name'] = name
    table.insert(self._params, obj)
  end
end

function Info:getType()
  return 'CPU'
end

return Info
