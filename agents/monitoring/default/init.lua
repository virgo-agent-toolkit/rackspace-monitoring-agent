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
local string = require('string')
local utils = require('utils')
local JSON = require('json')
local Object = require('core').Object
local fmt = require('string').format
local logging = require('logging')
local timer = require('timer')
local dns = require('dns')
local fs = require('fs')
local path = require('path')
local Emitter = require('core').Emitter

local sigarCtx = require('./sigar').ctx

local ConnectionStream = require('./client/connection_stream').ConnectionStream
local CrashReportSubmitter = require('./crashreport').CrashReportSubmitter
local constants = require('./util/constants')
local misc = require('./util/misc')
local States = require('./states')
local stateFile = require('./state_file')
local fsutil = require('./util/fs')
local UUID = require('./util/uuid')
local Setup = require('./setup').Setup

local table = require('table')

local MonitoringAgent = Emitter:extend()

function MonitoringAgent:_queryForEndpoints(domains, callback)
  local endpoints = ''
  function iter(domain, callback)
    dns.resolve(domain, 'SRV', function(err, results)
      if err then
        logging.error('Could not lookup SRV record from ' .. domain)
        callback()
        return
      end
      callback(nil, results)
    end)
  end
  async.map(domains, iter, function(err, results)
    local i, v, serverPort
    for i, v in pairs(results) do
      serverPort = results[i][1].name .. ':' .. results[i][1].port
      endpoints = endpoints .. serverPort
      logging.info('found endpoint: ' .. serverPort)
      if i ~= #results then
        endpoints = endpoints .. ','
      end
    end
    callback(nil, endpoints)
  end)
end

function MonitoringAgent:_getSystemId()
  local netifs = sigarCtx:netifs()
  for i=1, #netifs do
    local eth = netifs[i]:info()
    if eth['type'] ~= 'Local Loopback' then
      return UUID:new(eth.hwaddr):toString()
    end
  end
  return nil
end

function MonitoringAgent:_getPersistentFilename(variable)
  return path.join(constants.DEFAULT_PERSISTENT_VARIABLE_PATH, variable .. '.txt')
end

function MonitoringAgent:_savePersistentVariable(variable, data, callback)
  local filename = self:_getPersistentFilename(variable)
  fsutil.mkdirp(constants.DEFAULT_PERSISTENT_VARIABLE_PATH, "0644", function(err)
    if err and err.code ~= 'EEXIST' then
      callback(err)
      return
    end
    fs.writeFile(filename, data, callback)
  end)
end

function MonitoringAgent:_getPersistentVariable(variable, callback)
  local filename = self:_getPersistentFilename(variable)
  fs.readFile(filename, function(err, data)
    if err then
      callback(err)
      return
    end
    callback(nil, misc.trim(data))
  end)
end

function MonitoringAgent:setConfig(config)
  self._config = config
end

function MonitoringAgent:_verifyState(callback)

  if self._config['monitoring_token'] == nil then
    logging.error("'monitoring_token' is missing from 'config'")
    process.exit(1)
  end

  async.waterfall({
    -- retrieve persistent variables
    function(callback)
      if self._config['monitoring_id'] ~= nil then
        callback()
        return
      end

      self:_getPersistentVariable('monitoring_id', function(err, monitoring_id)
        local getSystemId
        getSystemId = function()
          monitoring_id = self:_getSystemId()
          if not monitoring_id then
            logging.error("could not retrieve system id... retrying")
            timer.setTimeout(5000, getSystemId)
            return
          end
          self._config['monitoring_id'] = monitoring_id
          self:_savePersistentVariable('monitoring_id', monitoring_id, callback)
        end

        if err and err.code ~= 'ENOENT' then
          callback(err)
        elseif err and err.code == 'ENOENT' then
          getSystemId()
        else
          self._config['monitoring_id'] = monitoring_id
          callback()
        end
      end)
    end,
    -- log
    function(callback)
      logging.debug('Using monitoring_id ' .. self._config['monitoring_id'])
      callback()
    end
  }, callback)
end

function MonitoringAgent:_loadEndpoints(callback)
  local endpoints
  local query_endpoints

  if not self._config['monitoring_query_endpoints'] then
    self._config['monitoring_query_endpoints'] = table.concat(constants.DEFAULT_MONITORING_SRV_QUERIES, ',')
  end

  if self._config['monitoring_query_endpoints'] and
     self._config['monitoring_endpoints'] == nil then
    -- Verify that the endpoint addresses are specified in the correct format
    query_endpoints = misc.split(self._config['monitoring_query_endpoints'], '[^,]+')
    logging.debug("querying for endpoints: ".. self._config['monitoring_query_endpoints'])
    self:_queryForEndpoints(query_endpoints, function(err, endpoints)
      if err then
        callback(err)
        return
      end
      self._config['monitoring_endpoints'] = endpoints
      callback()
    end)
  else
    -- Verify that the endpoint addresses are specified in the correct format
    endpoints = misc.split(self._config['monitoring_endpoints'], '[^,]+')
    if #endpoints == 0 then
      logging.error("at least one endpoint needs to be specified")
      process.exit(1)
    end
    for i, address in ipairs(endpoints) do
      if misc.splitAddress(address) == nil then
        logging.error("endpoint needs to be specified in the following format ip:port")
        process.exit(1)
      end
    end
    callback()
  end
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
    end,
    function(callback)
      self:_loadEndpoints(callback)
    end
  }, callback)
end

function MonitoringAgent:connect(callback)
  local endpoints = misc.split(self._config['monitoring_endpoints'], '[^,]+')
  if #endpoints <= 0 then
    logging.error('no endpoints')
    timer.setTimeout(misc.calcJitter(constants.SRV_RECORD_FAILURE_DELAY, constants.SRV_RECORD_FAILURE_DELAY_JITTER), function()
      process.exit(1)
    end)
    return
  end
  self._streams = ConnectionStream:new(self._config['monitoring_id'], self._config['monitoring_token'])
  self._streams:on('error', function(err)
    logging.error(JSON.stringify(err))
  end)
  self._streams:on('promote', function()
    self:emit('promote')
  end)
  self._streams:createConnections(endpoints, callback)
end

function MonitoringAgent:getStreams()
  return self._streams
end

function MonitoringAgent:initialize(stateDirectory)
  if not stateDirectory then stateDirectory = virgo.default_state_unix_directory end
  logging.debug('Using state directory ' .. stateDirectory)
  self._states = States:new(stateDirectory)
  self._config = virgo.config
end

function MonitoringAgent:getConfig()
  return self._config
end

function MonitoringAgent.run(argv)
  argv = argv and argv or {}
  local options = {}

  if argv.s then
    options.stateDirectory = argv.s
  end

  if argv.c then
    options.configFile = argv.c
  end

  if argv.p then
    options.pidFile = argv.p
  end

  local agent = MonitoringAgent:new(options.stateDirectory)

  -- setup will exit and not fall through
  if argv.u then
    options.configFile = options.configFile or constants.DEFAULT_CONFIG_PATH
    local setup = Setup:new(argv, options.configFile, agent)
    setup:run()
  else
    agent:start(options)
  end
end

function MonitoringAgent:_sendCrashReports(callback)
  local crashReports = {}
  local productName = virgo.default_name:gsub('%-', '%%%-')

  local function submitCrashReport(filename, callback)
    filename = "/tmp/" .. filename
    local crs = CrashReportSubmitter:new(filename, constants.CRASH_REPORT_URL)
    crs:run(function (err)
      if (err) then
        callback(err)
        return
      end
      fs.unlink(filename, callback)
    end)
  end

  async.series({
    function(callback)
      fs.readdir("/tmp", function (err, files)
        if err then
          callback(err)
        end

        for index,value in ipairs(files) do
          if string.find(value, productName .. "%-crash%-report-.+.dmp") ~= nil then
            logging.info('Found previous crash report /tmp/' .. value)
            table.insert(crashReports, value)
          end
        end
        callback()
      end)
    end,
    function(callback)
      async.forEachSeries(crashReports, submitCrashReport, callback)
    end
  }, callback)
end

function MonitoringAgent:start(options)
  if self:getConfig() == nil then
    logging.error("config missing or invalid")
    process.exit(1)
  end

  async.series({
    function(callback)
      self:_sendCrashReports(callback)
    end,
    function(callback)
      misc.writePid(options.pidFile, callback)
    end,
    function(callback)
      self:loadStates(callback)
    end,
    function(callback)
      self:connect(callback)
    end
  },
  function(err)
    if err then
      logging.error(err.message)
    end
  end)
end

return MonitoringAgent
