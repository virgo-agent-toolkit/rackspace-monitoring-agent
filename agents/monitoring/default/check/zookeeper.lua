--[[
Copyright 2012 Rackspace

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

local table = require('table')
local net = require('net')

local BaseCheck = require('./base').BaseCheck
local CheckResult = require('./base').CheckResult
local split = require('../util/misc').split

local METRICS_MAP = {
  zk_version = { type = 'string', alias = 'version' },
  zk_avg_latency = { type = 'uint32', alias = 'avg_latency' },
  zk_max_latency = { type = 'uint32', alias = 'max_latency' },
  zk_min_latency = { type = 'uint32', alias = 'min_latency' },
  zk_packets_sent = { type = 'gauge', alias = 'packets_sent' },
  zk_packets_received = { type = 'gauge', alias = 'packets_received'},
  zk_num_alive_connections = { type = 'uint32', alias = 'num_alive_connections' },
  zk_outstanding_requests = { type = 'uint32', alias = 'outstanding_requests' },
  zk_server_state = { type = 'string', alias = 'server_state' },
  zk_znode_count = { type = 'uint32', alias = 'znode_count' },
  zk_watch_count = { type = 'uint32', alias = 'watch_count' },
  zk_approximate_data_size = { type = 'uint32', alias = 'approximate_data_size' },
  zk_open_file_descriptor_count = { type = 'uint32', alias = 'open_file_descriptor_count' },
  zk_max_file_descriptor_count = { type = 'uint32', alias = 'max_file_descriptor_count' },
  zk_followers = { type = 'uint32', alias = 'followers' },
  zk_synced_followers = { type = 'uint32', alias = 'synced_followers' },
  zk_pending_syncs = { type = 'uint32', alias = 'pending_syncs' }
}

local ZooKeeperCheck = BaseCheck:extend()
function ZooKeeperCheck:initialize(params)
  BaseCheck.initialize(self, 'agent.zookeeper', params)

  self._host = params.details.host and params.details.host or 'localhost'
  self._port = params.details.port and params.details.port or 2181
end

function ZooKeeperCheck:_parseResponse(data)
  local result = {}, item, mapItem, value

  lines = data:gmatch('([^\n]*)\n')
  for line in lines do
    item = self:_parseLine(line)
    mapItem = METRICS_MAP[item['key']]

    if mapItem ~= nil then
      result[item['key']] = {name = mapItem['alias'], type = mapItem['type'],
                             value = item['value']}
    end
  end

  return result
end

function ZooKeeperCheck:_parseLine(line)
  local parts = split(line, '[^%s]+')
  local result = {}, value

  if #parts < 2 then
    return nil
  end


  result['key'] = parts[1]

  if parts[1] == 'zk_version' then
    -- Version is in the following format "3.4.4--1, built on 09/24/2012 22:48 GMT"
    table.remove(parts, 1)
    value = table.concat(parts, ' ')
  else
    value = parts[2]
  end

  result['value'] = value

  return result
end

function ZooKeeperCheck:run(callback)
  local checkResult = CheckResult:new(self, {})
  local client

  client = net.createConnection(self._port, self._host, function(err)
    local buffer = ''

    if err then
      checkResult:setError(err.message)
      callback(checkResult)
      return
    end

    client:on('data', function(data)
      buffer = buffer .. data
    end)

    client:on('end', function()
      local result = self:_parseResponse(buffer)
      local i = 0

      for k, v in pairs(result) do
        i = i + 1
        checkResult:addMetric(v['name'], nil, v['type'], v['value'])
      end

      if i == 0 then
        -- Only ZooKeeper 3.4.0 and above supports "mntr" command
        checkResult:setError('Empty response or running ZooKeeper < 3.4.0')
      end

      callback(checkResult)
    end)

    client:write('mntr\n')
  end)

  client:on('error', function(err)
    checkResult:setError(err.message)
    callback(checkResult)
  end)
end

local exports = {}
exports.ZooKeeperCheck = ZooKeeperCheck
return exports
