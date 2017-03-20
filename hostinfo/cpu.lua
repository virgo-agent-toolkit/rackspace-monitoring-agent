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
local async = require('async')
local sigar = require('sigar')
local timer = require('timer')

local SAMPLE_RATE = 350 -- ms
local DATA_FIELDS = {
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
local INFO_FIELDS = {
  'mhz',
  'model',
  'total_cores',
  'total_sockets',
  'vendor'
}


--[[ Info ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  local samples = {}
  local function sample(callback)
    local ctx = sigar:new()
    local cpus = ctx:cpus()
    local result = {}
    for i=1, #cpus do
      local obj = {}
      local info = cpus[i]:info()
      local data = cpus[i]:data()
      local name = 'cpu.' .. i - 1
      for _, v in pairs(DATA_FIELDS) do
        obj[v] = data[v]
      end
      for _, v in pairs(INFO_FIELDS) do
        obj[v] = info[v]
      end
      obj['name'] = name
      table.insert(result, obj)
    end
    table.insert(samples, result)
    callback()
  end
  async.series({
    function(callback)
      sample(callback)
    end,
    function(callback)
      timer.setTimeout(SAMPLE_RATE, callback)
    end,
    function(callback)
      sample(callback)
    end
  }, function()
    for cpuIndex in pairs(samples[1]) do
      local cpuDiff = {}
      cpuDiff['name'] = samples[1][cpuIndex]['name']
      for _, v in pairs(DATA_FIELDS) do
        local cpuValue = samples[1][cpuIndex][v]
        local cpuValue2 = samples[2][cpuIndex][v]
        cpuDiff[v] = cpuValue2 - cpuValue
      end
      for _, v in pairs(INFO_FIELDS) do
        cpuDiff[v] = samples[2][cpuIndex][v]
      end
      table.insert(self._params, cpuDiff)
    end
    callback()
  end)
end

function Info:getType()
  return 'CPU'
end

return Info
