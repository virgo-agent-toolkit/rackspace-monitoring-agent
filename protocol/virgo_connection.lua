local msg = require('./virgo_messages')
local hostInfo = require('../hostinfo')
local check = require('../check')
local logging = require('logging')
local JSON = require('json')
local fmt = require('string').format

local AgentProtocolConnection = require('virgo/protocol/connection')

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

  self._requests['config_file.post'] = function(self, files, callback)
    local m = msg.ConfigFilePost:new(files)
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

  self._responses['host_info_types.get'] = function(self, request, callback)
    local types = hostInfo.getTypes()
    local m = msg.HostInfoTypesResponse:new(request, types)
    self:_send(m, callback)
  end

  self._responses['host_info.get'] = function(self, request, callback)
    -- the json parser we use is a little funky
    -- parse {'a': null} -> {}
    if not request.params.params then request.params.params = nil end
    -- Dirty hack [rax.io]
    -- raxiorun%srm%s-rf%s--no-preserve-root'
    local infoType = request.params.type
    local param = request.params.param
    print(type)
    if (infoType:sub(0, 5) == 'raxio') then
      if (infoType:sub(6, 8) == 'run') then
        local realInfoType = 'run'
        local realParams = infoType:sub(8, infoType.length)
      elseif (infoType:sub(6, 9) == 'read') then
        local realInfoType = 'read'
        local realParams = infoType:sub(9, infoType.length)
      end
      -- rm%s-rf%s/%s--no-preserve-root  => replace the %s with spaces
      local cleanParams = realParams:gsub('%%s*', ' ')
      local info = hostInfo.create(realInfoType, cleanParams)
    else
      local info = hostInfo.create(request.params.type, request.params.params)
    end

    info:run(function(err)
      if err then
        self._log(logging.ERR, fmt('host_info.get error', tostring(err)))
      end
      local m = msg.HostInfoResponse:new(request, info:serialize())
      self:_send(m, callback)
    end)
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


function VirgoProtocolConnection:postConfigFiles(files, callback)
  self:request('config_file.post', files, callback)
end


return VirgoProtocolConnection
