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
local sigar = require('sigar')
local table = require('table')


--[[ Info ]]--
local Info = HostInfo:extend()

function Info:initialize()
  HostInfo.initialize(self)
end
function Info:_run(callback)
  local ctx = sigar:new()
  local netifs = ctx:netifs()
  for i=1,#netifs do
    local info = netifs[i]:info()
    local usage = netifs[i]:usage()
    local name = info.name
    local obj = {}

    local info_fields = {
      'address',
      'address6',
      'broadcast',
      'flags',
      'hwaddr',
      'mtu',
      'name',
      'netmask',
      'type'
    }
    local usage_fields = {
      'rx_packets',
      'rx_bytes',
      'rx_errors',
      'rx_overruns',
      'rx_dropped',
      'tx_packets',
      'tx_bytes',
      'tx_errors',
      'tx_overruns',
      'tx_dropped',
      'tx_collisions',
      'tx_carrier',
    }

    if info then
      for _, v in pairs(info_fields) do
        obj[v] = info[v]
      end
    end
    if usage then
      for _, v in pairs(usage_fields) do
        obj[v] = usage[v]
      end
    end
    obj['name'] = name
    table.insert(self._params, obj)
  end
  callback()
end

function Info:getType()
  return 'NETWORK'
end

return Info
