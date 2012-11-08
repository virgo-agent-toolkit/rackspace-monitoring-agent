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

local string = require('string')
local utils = require('utils')
local JSON = require('json')
local timer = require('timer')
local dns = require('dns')
local fs = require('fs')
local os = require('os')
local path = require('path')
local table = require('table')
local Object = require('core').Object

local fmt = require('string').format
local Emitter = require('core').Emitter
local async = require('async')
local sigarCtx = require('./sigar').ctx

local constants = require('./util/constants')
local misc = require('./util/misc')
local States = require('./states')
local stateFile = require('./state_file')
local fsutil = require('./util/fs')
local UUID = require('./util/uuid')
local version = require('./util/version')
local logging = require('logging')
local vtime = require('virgo-time')
local Endpoint = require('./endpoint').Endpoint
local ConnectionStream = require('./client/connection_stream').ConnectionStream
local CrashReporter = require('./crashreport').CrashReporter
local MonitoringAgent = Emitter:extend()

function MonitoringAgent:initialize(options)
  if not options.stateDirectory then
    options.stateDirectory = constants.DEFAULT_STATE_PATH
  end
  logging.debug('Using state directory ' .. options.stateDirectory)
  self._stateDirectory = options.stateDirectory
  self._states = States:new(options.stateDirectory)
  self._config = virgo.config
  self._options = options
end

function MonitoringAgent:start(options)
  if self:getConfig() == nil then
    logging.error("config missing or invalid")
    process.exit(1)
  end

  async.series({
    function(callback)
      self:loadEndpoints(callback)
    end,
    function(callback)
      local dump_dir = virgo_paths.get(virgo_paths.VIRGO_PATH_PERSISTENT_DIR)
      local endpoints = self._config['monitoring_endpoints']
      local reporter = CrashReporter:new(version.process, version.bundle, virgo.platform, dump_dir, endpoints)
      reporter:submit(function(err, res)
        callback()
      end)
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
  local endpoints = self._config['monitoring_endpoints']

  if #endpoints <= 0 then
    logging.error('no endpoints')
    timer.setTimeout(misc.calcJitter(constants.SRV_RECORD_FAILURE_DELAY, constants.SRV_RECORD_FAILURE_DELAY_JITTER), function()
      process.exit(1)
    end)
    return
  end
  self._streams = ConnectionStream:new(self._config['monitoring_id'],
                                       self._config['monitoring_token'],
                                       self._config['monitoring_guid'],
                                       self._options)
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

function MonitoringAgent:getConfig()
  return self._config
end

function MonitoringAgent:setConfig(config)
  self._config = config
end

function MonitoringAgent:getStreams()
  return self._streams
end

function MonitoringAgent:getConfig()
  return self._config
end

function MonitoringAgent:setConfig(config)
  self._config = config
end

function MonitoringAgent:_verifyState(callback)

  if self._config['monitoring_token'] == nil then
    logging.error("'monitoring_token' is missing from 'config'")
    process.exit(1)
  end

  -- Regen GUID
  self._config['monitoring_guid'] = self:_getSystemId()

  async.series({
    -- retrieve persistent variables
    function(callback)
      if self._config['monitoring_id'] ~= nil then
        callback()
        return
      end

      self:_getPersistentVariable('monitoring_id', function(err, monitoring_id)
        local getSystemId
        getSystemId = function(callback)
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
          return
        elseif err and err.code == 'ENOENT' then
          getSystemId(callback)
        else
          self._config['monitoring_id'] = monitoring_id
          callback()
        end
      end)
    end,
    -- log
    function(callback)
      logging.infof('Starting agent %s (guid=%s, version=%s, bundle_version=%s)',
                      self._config['monitoring_id'],
                      self._config['monitoring_guid'],
                      version.process,
                      version.bundle)
      callback()
    end
  }, callback)
end


function MonitoringAgent:loadEndpoints(callback)
  local config = self._config
  local queries = config['monitoring_query_endpoints'] or table.concat(constants.DEFAULT_MONITORING_SRV_QUERIES, ',')
  local endpoints = config['monitoring_endpoints']

  local function _callback(err, endpoints)
    if err then return callback(err) end

    for _, ep in pairs(endpoints) do
      if not ep.host or not ep.port then
        logging.errorf("Invalid endpoint: %s, %s", ep.host or "", ep.port or  "")
        process.exit(1)
      end
    end
    config['monitoring_endpoints'] = endpoints
    callback(nil, endpoints)
  end

  if queries and not endpoints then
    local domains = misc.split(queries, '[^,]+')
    return self:_queryForEndpoints(domains, _callback)
  end
  -- split address,address,address
  endpoints = misc.split(endpoints, '[^,]+')

  if #endpoints == 0 then
    logging.error("at least one endpoint needs to be specified")
    process.exit(1)
  end

  local new_endpoints = {}

  for _, address in ipairs(endpoints) do
    table.insert(new_endpoints, Endpoint:new(address))
  end

  return _callback(nil, new_endpoints)
end

function MonitoringAgent:_queryForEndpoints(domains, callback)
  function iter(domain, callback)
    dns.resolve(domain, 'SRV', function(err, results)
      if err then
        logging.errorf('Could not lookup SRV record from %s', domain)
        callback()
        return
      end
      callback(nil, results)
    end)
  end
  local endpoints = {}
  async.map(domains, iter, function(err, results)
    local endpoint, _
    for _, endpoint in pairs(results) do
      -- results are wrapped in a table...
      endpoint = endpoint[1]
      -- get anem and port
      endpoint = Endpoint:new(endpoint.name, endpoint.port)
      logging.infof('found endpoint: %s', tostring(endpoint))
      table.insert(endpoints, endpoint)
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
  fsutil.mkdirp(constants.DEFAULT_PERSISTENT_VARIABLE_PATH, "0755", function(err)
    if err and err.code ~= 'EEXIST' then
      callback(err)
      return
    end
    fs.writeFile(filename, data, function(err)
      callback(err, filename)
    end)
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

return { MonitoringAgent = MonitoringAgent }
