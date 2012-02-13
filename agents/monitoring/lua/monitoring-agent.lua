local async = require('async')
local utils = require('utils')
local Object = require('core').Object
local logging = require('logging')

local ConnectionStream = require('./lib/client/connection_stream').ConnectionStream
local States = require('./lib/states')

local MonitoringAgent = Object:extend()

function MonitoringAgent:sample()
  local HTTP = require("http")
  local Utils = require("utils")
  local logging = require('logging')
  local s = sigar:new()
  local sysinfo = s:sysinfo()
  local cpus = s:cpus()
  local netifs = s:netifs()
  local i = 1;

  HTTP.createServer("0.0.0.0", 8080, function (req, res)
    local body = Utils.dump({req=req,headers=req.headers}) .. "\n"
    res:write_head(200, {
      ["Content-Type"] = "text/plain",
      ["Content-Length"] = #body
    })
    res:finish(body)
  end)

  print("sigar.sysinfo = ".. Utils.dump(sysinfo))

  while i <= #cpus do
    print("sigar.cpus[".. i .."].info = ".. Utils.dump(cpus[i]:info()))
    print("sigar.cpus[".. i .."].data = ".. Utils.dump(cpus[i]:data()))
    i = i + 1
  end

  i = 1;

  while i <= #netifs do
    print("sigar.netifs[".. i .."].info = ".. Utils.dump(netifs[i]:info()))
    print("sigar.netifs[".. i .."].usage = ".. Utils.dump(netifs[i]:usage()))
    i = i + 1
  end

  logging.log(logging.CRIT, "Server listening at http://localhost:8080/")
end

function MonitoringAgent:_verifyState(callback)
  callback = callback or function() end
  self._config = self._states:get('config')
  if self._config == nil then
    logging.log(logging.ERR, "statefile 'config' missing or invalid")
    process.exit(1)
  end
  if self._config['id'] == nil then
    logging.log(logging.ERR, "'id' is missing from 'config'")
    process.exit(1)
  end
  if self._config['token'] == nil then
    logging.log(logging.ERR, "'token' is missing from 'config'")
    process.exit(1)
  end
  logging.log(logging.INFO, "using id " .. self._config['id'])
  callback()
end

function MonitoringAgent:loadStates(callback)
  async.series({
    -- Load the States
    function(callback)
      self._states:load(callback)
    end,
    -- Verify
    function(callback)
      self:_verifyState(callback)
    end
  }, function(err)
    callback(err)
  end)
end

function MonitoringAgent:connect(callback)
  self._streams = ConnectionStream:new(self._config['id'], self._config['token'])
  self._streams:on('error', function(err)
    logging.log(logging.ERR, err.message)
  end)
  self._streams:createConnection('ord1', 'localhost', 50040, callback)
end

function MonitoringAgent:initialize()
  self._states = States:new('/var/run/agent/states')
end

function MonitoringAgent.run()
  local agent = MonitoringAgent:new()
  async.waterfall({
    function(callback)
      agent:loadStates(callback)
    end,
    function(callback)
      agent:connect(callback)
    end
  }, function(err)
    if err then
      logging.log(logging.ERR, err.message)
    end
  end)
end

return MonitoringAgent

