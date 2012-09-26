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

local METRICS_NAME_MAP = {
  zk_version = 'version',
  zk_avg_latency = 'avg_latency',
  zk_max_latency = 'max_latency',
  zk_min_latency = 'min_latency',
  zk_packets_sent = 'packets_sent',
  zk_packets_received = 'packets_received',
  zk_num_alive_connections = 'num_alive_connections',
  zk_outstanding_requests = 'outstanding_requests',
  zk_server_state = 'server_state',
  zk_znode_count = 'znode_count',
  zk_watch_count = 'watch_count',
  zk_approximate_data_size = 'approximate_data_size',
  zk_open_file_descriptor_count = 'open_file_descriptor_count',
  zk_max_file_descriptor_count = 'max_file_descriptor_count',
  zk_followers = 'followers',
  zk_synced_followers = 'synced_followers',
  zk_pending_syncs = 'pending_syncs'
}

local METRICS_TYPE_MAP = {
  zk_version = 'string',
  zk_avg_latency = 'uint32',
  zk_max_latency = 'uint32',
  zk_min_latency = 'uint32',
  zk_packets_sent = 'gauge',
  zk_packets_received = 'gauge',
  zk_num_alive_connections = 'uint32',
  zk_outstanding_requests = 'uint32',
  zk_server_state = 'string',
  zk_znode_count = 'uint32',
  zk_watch_count = 'uint32',
  zk_approximate_data_size = 'uint32',
  zk_open_file_descriptor_count = 'uint32',
  zk_max_file_descriptor_count = 'uint32',
  zk_followers = 'uint32',
  zk_synced_followers = 'uint32',
  zk_pending_syncs = 'uint32'
}

local ZooKeeperCheck = BaseCheck:extend()
function ZooKeeperCheck:initialize(params)
  BaseCheck.initialize(self, 'agent.zookeeper', params)

  self._host = params.details.host and params.details.host or 'localhost'
  self._port = params.details.port and params.details.port or 2181
end

function ZooKeeperCheck:_parseResponse(data)
  local result = {}, item, metricName, metricType, value

  lines = data:gmatch('([^\n]*)\n')
  for line in lines do
    item = self:_parseLine(line)
    metricName = METRICS_NAME_MAP[item['key']]
    metricType = METRICS_TYPE_MAP[item['key']]

    if item and metricName then
      result[item['key']] = {name = metricName, type = metricType, value = item['value']}
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
