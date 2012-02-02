local async = require('async')
local logging = require('logging')
local Object = require('object')
local States = require('./states')
local utils = require('utils')

local MonitoringAgent = Object:extend()

function MonitoringAgent.prototype:sample()
  local HTTP = require("http")
  local Utils = require("utils")
  local s = sigar:new()
  local sysinfo = s:sysinfo()
  local cpus = s:cpus()
  local netifs = s:netifs()
  local i = 1;

  HTTP.create_server("0.0.0.0", 8080, function (req, res)
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

function MonitoringAgent.prototype:initialize(callback)
  self._states = States:new('/var/run/agent/states')
end

function MonitoringAgent.prototype:load(callback)
  async.waterfall({
    -- Load States
    function(callback)
      self._states:load(callback)
    end
  }, callback)
end

function MonitoringAgent.run()
  local agent = MonitoringAgent:new()
  async.series({
    function(callback)
      agent:load(callback);
    end
  }, function(err)
    if err then
      logging.log(logging.CRIT, err.message)
      return
    end
  end)
end

return MonitoringAgent

