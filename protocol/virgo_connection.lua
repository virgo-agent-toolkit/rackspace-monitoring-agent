--[[
Copyright 2013 Rackspace

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
local msg = require('./virgo_messages')
local hostInfo = require('../host_info')
local check = require('../check')
local JSON = require('json')

local AgentProtocolConnection = require('./connection')

local VirgoProtocolConnection = AgentProtocolConnection:extend()
function VirgoProtocolConnection:initialize(log, myid, token, guid, conn)
  AgentProtocolConnection.initialize(self, log, myid, token, guid, conn)
  self:_bindHandlers()
end

function VirgoProtocolConnection:_bindHandlers()

  self._requests['check_schedule.get'] = function(self, callback)
    local m = msg.Manifest:new()
    self:_send(m, callback)
  end

  self._requests['check_metrics.post'] = function(self, check, checkResult, callback)
    local m = msg.MetricsRequest:new(check, checkResult)
    self:_send(m, callback)
  end

  self._responses['check_schedule.changed'] = function(self, replyTo, callback)
    local m = msg.ScheduleChangeAck:new(replyTo)
    self:_send(m, callback)
  end

  self._responses['system.info'] = function(self, request, callback)
    local m = msg.SystemInfoResponse:new(request)
    self:_send(m, callback)
  end

  self._responses['host_info.get'] = function(self, request, callback)
    local info = hostInfo.create(request.params.type)
    local m = msg.HostInfoResponse:new(request, info:serialize())
    self:_send(m, callback)
  end

  self._responses['check.targets'] = function(self, request, callback)
    if not request.params.type then
      return
    end
    check.targets(request.params.type, function(err, targets)
      local m = msg.CheckTargetsResponse:new(request, targets)
      self:_send(m, callback)
    end)
  end

  self._responses['check.test'] = function(self, request, callback)
    local status, checkParams = pcall(function()
      return JSON.parse(request.params.checkParams)
    end)
    if not status then
      return
    end
    checkParams.period = 30
    check.test(checkParams, function(err, ch, results)
      local m = msg.CheckTestResponse:new(request, results)
      self:_send(m, callback)
    end)
  end

end

return VirgoProtocolConnection
