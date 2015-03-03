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
local timer = require('timer')
local net = require('net')
local Error = require('core').Error

local async = require('async')

local BaseCheck = require('./base').BaseCheck
local CheckResult = require('./base').CheckResult
local split = require('virgo/util/misc').split
local trim = require('virgo/util/misc').trim
local fireOnce = require('virgo/util/misc').fireOnce

local MAX_BUFFER_LENGTH = 1024 * 1024 * 1 -- 1 MB

local METRICS_MAP = {
  redis_version = { type = 'string', alias = 'version' },
  uptime_in_seconds = { type = 'uint32' },
  connected_clients = { type = 'uint32' },
  blocked_clients = { type = 'uint32' },
  used_memory = { type = 'uint64' },
  bgsave_in_progress = { type = 'uint32' },
  changes_since_last_save = { type = 'uint32' },
  bgrewriteaof_in_progress = { type = 'uint32' },
  total_connections_received = { type = 'gauge' },
  total_commands_processed = { type = 'gauge' },
  expired_key = { type = 'uint32' },
  evicted_keys = { type = 'uint32' },
  pubsub_patterns = { type = 'uint32' }
}

local RedisCheck = BaseCheck:extend()
function RedisCheck:initialize(params)
  BaseCheck.initialize(self, params)

  self._host = params.details.host or 'localhost'
  self._port = params.details.port or 6379
  self._password = params.details.password or nil
  self._timeout = params.details.timeout or 5000
end

function RedisCheck:getType()
  return 'agent.redis'
end

function RedisCheck:_parseResponse(data)
  local result = {}
  local item
  local mapItem
  local name

  lines = data:gmatch('([^\n]*)\n')
  for line in lines do
    item = self:_parseLine(line)

    if item then
      mapItem = METRICS_MAP[item['key']]
    else
      mapItem = nil
    end

    if mapItem ~= nil then
      name = mapItem['alias'] and mapItem['alias'] or item['key']
      result[name] = {name = name, type = mapItem['type'],
                             value = item['value']}
    end
  end

  return result

end

function RedisCheck:_parseLine(line)
  local parts = split(line, '[^:]+')
  local result = {}, value

  if #parts < 2 then
    return nil
  end


  result['key'] = trim(parts[1])
  result['value'] = trim(parts[2])

  return result
end

function RedisCheck:run(callback)
  local checkResult = CheckResult:new(self, {})
  local client
  local connected = false

  async.series({
    function(callback)
      local wrappedCallback = fireOnce(callback)

      -- Connect
      client = net.createConnection(self._port, self._host, wrappedCallback)
      client:setTimeout(self._timeout)
      client:on('error', wrappedCallback)
      client:on('timeout', function()
        wrappedCallback(Error:new('Connection timed out in ' .. self._timeout .. 'ms'))
      end)
    end,

    function(callback)
      local buffer = ''
      -- Try to authenticate if password is provided
      if not self._password then
        callback()
        return
      end

      connected = true

      client:on('data', function(data)
        buffer = buffer .. data

        if buffer:lower():find('+ok') then
          callback()
        elseif buffer:lower():find('-err invalid password') then
          callback(Error:new('Could not authenticate. Invalid password.'))
        elseif buffer:len() > MAX_BUFFER_LENGTH then
          callback(Error:new('Maximum buffer length reached'))
        end
      end)

      client:write('AUTH ' .. self._password .. '\r\n')
    end,

    function(callback)
      local buffer = ''

      client:removeListener('data')
      client:removeListener('end')

      -- Retrieve stats
      client:on('data', function(data)
        if buffer:len() < MAX_BUFFER_LENGTH then
          buffer = buffer .. data
        else
          callback(Error:new('Maximum buffer length reached'))
        end
      end)

      client:on('end', function()
        local result

        if buffer:lower():find('-err operation not permitted') then
          callback(Error:new('Could not authenticate. Missing password?'))
          return
        end

        if buffer:lower():find('-err invalid password') then
          callback(Error:new('Could not authenticate. Invalid password.'))
          return
        end

        result = self:_parseResponse(buffer)

        for k, v in pairs(result) do
          checkResult:addMetric(v['name'], nil, v['type'], v['value'])
        end

        callback()
      end)

      client:write('INFO\r\n')
      client:write('QUIT\r\n')
    end
  },

  function(err)
    if err then
      checkResult:setError(err.message)
    end

    if connected then
      client:shutdown()
    end

    callback(checkResult)
  end)
end

local exports = {}
exports.RedisCheck = RedisCheck
return exports
