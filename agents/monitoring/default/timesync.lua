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

local Object = require('core').Object
local consts = require('./util/constants')
local logging = require('logging')
local timer = require('timer')
local utils = require('utils')
local vtime = require('virgo-time')

local TimeSync = Object:extend()
function TimeSync:initialize(conn_stream)
  self.conn_stream = conn_stream
  self.timer = nil
  self.started = false
end

function TimeSync:_tick(callback)
  callback = callback or function() end
  logging.info('Synchronizing Time')
  local client = self.conn_stream:getClient()
  if not client then
    logging.info('zero active clients')
    return
  end
  local agentDepartureTs = vtime.now() -- T1
  client.protocol:sendHeartbeat(function(err, result)
    if err then
      logging.errorf('Error on timesync', err)
      callback(err)
      return
    end
    local agentReceivedTs = vtime.now() -- T2
    local endpointTimestamp = result.response_timestamp
    vtime.timesync(agentDepartureTs, endpointTimestamp,
      endpointTimestamp, agentReceivedTs, callback)
  end)
end

function TimeSync:start()
  if self.started then
    return
  end
  local interval = consts.DEFAULT_TIMESYNC_INTERVAL
  self.started = true
  self:_tick(function()
    self.timer = timer.setInterval(interval, utils.bind(TimeSync._tick, self))
  end)
end

function TimeSync:stop()
  if self.started == false or not self.timer then
    return
  end
  timer.clearInterval(self.timer)
  self.timer = nil
  self.started = false
end

local exports = {}
exports.TimeSync = TimeSync
return exports
