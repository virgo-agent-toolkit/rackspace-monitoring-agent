local async = require('async')
local utils = require('utils')
local Object = require('core').Object

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

function MonitoringAgent:initialize(callback)
  self._states = States:new('/var/run/agent/states')
  self._streams = ConnectionStream:new('MYID', '0a6f36218f07a3cfc69e822a22b631ebfba5a331706ffecd99b2f3988383e5e2:7777')
  async.waterfall({
    -- Load States
    function(callback)
      self._states:load(callback)
    end,
    function(callback)
      self._streams:createConnection('ord1', 'localhost', 50040, callback)
    end
  }, callback)
end

function MonitoringAgent.run()
  local agent
  agent = MonitoringAgent:new(function(err)
    if err then
      p(err)
      return
    end
  end)
end

return MonitoringAgent

