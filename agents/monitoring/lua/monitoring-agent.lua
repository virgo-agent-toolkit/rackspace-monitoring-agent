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


local async = require('async')
local utils = require('utils')
local Object = require('core').Object
local fmt = require('string').format
local logging = require('logging')

local ConnectionStream = require('./lib/client/connection_stream').ConnectionStream
local misc = require('./lib/util/misc')
local States = require('./lib/states')
local stateFile = require('./lib/state_file')

local MonitoringAgent = Object:extend()

DEFAULT_STATE_DIRECTORY = '/var/run/agent/states'

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

  if self._config['endpoints'] == nil then
    logging.log(logging.ERR, "'endpoints' is missing from 'config'")
    process.exit(1)
  end

  -- Verify that the endpoint addresses are specified in the correct format
  local endpoints = misc.split(self._config['endpoints'], '[^,]+')

  if #endpoints == 0 then
    logging.log(logging.ERR, "at least one endpoint needs to be specified")
    process.exit(1)
  end

  for i, address in ipairs(endpoints) do
    if misc.splitAddress(address) == nil then
      logging.log(logging.ERR, "endpoint needs to be specified in the following format ip:port")
      process.exit(1)
    end
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
  }, callback)
end

function MonitoringAgent:connect(callback)
  local endpoints = misc.split(self._config['endpoints'], '[^,]+')
  self._streams = ConnectionStream:new(self._config['id'], self._config['token'])
  self._streams:on('error', function(err)
    logging.log(logging.ERR, fmt('%s:%d -> %s', err.host, err.port, err.message))
  end)
  self._streams:createConnections(endpoints, callback)
end

function MonitoringAgent:initialize(stateDirectory, configFile)
  if not stateDirectory then stateDirectory = virgo.default_state_unix_directory end
  logging.log(logging.INFO, 'Using state directory ' .. stateDirectory)
  self._states = States:new(stateDirectory)
  self._config = virgo.config
end

function MonitoringAgent.run(options)
  if not options then options = {} end
  local agent = MonitoringAgent:new(options.stateDirectory, options.configFile)
  async.waterfall({
    function(callback)
      agent:loadStates(callback)
    end,
    function(callback)
      agent:connect(callback)
    end
  },
  function(err)
    if err then
      logging.log(logging.ERR, err.message)
    end
  end)
end

return MonitoringAgent
