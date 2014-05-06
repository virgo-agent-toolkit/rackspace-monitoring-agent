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
local sigarCtx = require('/sigar').ctx

local MachineIdentity = require('machineidentity').MachineIdentity
local constants = require('/constants')
local misc = require('/base/util/misc')
local fsutil = require('/base/util/fs')
local UUID = require('/base/util/uuid')
local logging = require('logging')
local endpoint = require('/endpoint')
local ConnectionStream = require('/base/client/connection_stream').ConnectionStream
local CrashReporter = require('/crashreport').CrashReporter
local Agent = Emitter:extend()
local Confd = require('confd')

function Agent:initialize(options, types)
  if not options.stateDirectory then
    options.stateDirectory = constants:get('DEFAULT_STATE_PATH')
  end
  logging.debug('Using state directory ' .. options.stateDirectory)
  self._stateDirectory = options.stateDirectory
  self._config = virgo.config
  self._options = options
  self._upgradesEnabled = true
  self._types = types or {}
  self._confd = Confd:new(options.confdDir, options.stateDirectory)
end

function Agent:start(options)
  if self:getConfig() == nil then
    logging.error("config missing or invalid")
    process.exit(1)
  end

  async.series({
    function(callback)
      self:_preConfig(callback)
    end,
    function(callback)
      self:loadEndpoints(callback)
    end,
    function(callback)
      local dump_dir = virgo_paths.get(virgo_paths.VIRGO_PATH_PERSISTENT_DIR)
      local endpoints = self._config['endpoints']
      local reporter = CrashReporter:new(virgo.virgo_version, virgo.bundle_version, virgo.platform, dump_dir, endpoints)
      reporter:submit(function(err)
        if err then
          logging.info(fmt('CrashReporter done with errors: %s', tostring(err)))
        else
          logging.info('CrashReporter done without errors')
        end
      end)
      callback()
    end,
    function(callback)
      if os.type() ~= 'win32' then
        if not options.pidFile then
          options.pidFile = constants:get('DEFAULT_PID_FILE_PATH')
        end
      end
      misc.writePid(options.pidFile, callback)
    end,
    function(callback)
      self:connect(callback)
    end,
    function(callback)
      self._confd:setup(callback)
    end
  },
  function(err)
    if err then
      logging.error(err.message)
    end
  end)
end

function Agent:connect(callback)
  local endpoints = self._config['endpoints']
  local upgradeStr = self._config['upgrade']
  if upgradeStr then
    upgradeStr = upgradeStr:lower()
    if upgradeStr == 'false' or upgradeStr == 'disabled' then
      self._upgradesEnabled = false
    end
  end

  if #endpoints <= 0 then
    logging.error('no endpoints')
    timer.setTimeout(misc.calcJitter(constants:get('SRV_RECORD_FAILURE_DELAY'), constants:get('SRV_RECORD_FAILURE_DELAY_JITTER')), function()
      process.exit(1)
    end)
    return
  end

  -- ReEnable upgrades when we have a handle on them
  self._upgradesEnabled = false

  logging.info(fmt('Upgrades are %s', self._upgradesEnabled and 'enabled' or 'disabled'))

  local connectionStreamType = self._types.ConnectionStream or ConnectionStream
  self._streams = connectionStreamType:new(self._config['id'],
                                       self._config['token'],
                                       self._config['guid'],
                                       self._upgradesEnabled,
                                       self._options,
                                       self._types)
  self._streams:on('error', function(err)
    logging.error(JSON.stringify(err))
  end)
  self._streams:on('promote', function(stream)
    local conn = stream:getClient().protocol
    local entity = stream:getEntityId()
    self._confd:runOnce(conn, entity, function()
      self:emit('promote')
    end)
  end)

  self._streams:createConnections(endpoints, callback)
end

function Agent:_shutdown(msg, timeout, exit_code, shutdownType)
  if shutdownType == constants:get('SHUTDOWN_RESTART') then
    virgo.perform_restart_on_upgrade()
  else
    -- Sleep to keep from busy restarting on upstart/systemd/etc
    timer.setTimeout(timeout, function()
      if msg then
        logging.info(msg)
      end
      process.exit(exit_code)
    end)
  end
end

function Agent:_onShutdown(shutdownType)
  local sleep = 0
  local timeout = 0
  local exit_code = 0
  local msg

  -- Destroy Socket Streams
  self._streams:shutdown()

  if shutdownType == constants:get('SHUTDOWN_UPGRADE') then
    msg = 'Shutting down agent due to upgrade'
  elseif shutdownType == constants:get('SHUTDOWN_RATE_LIMIT') then
    msg = 'Shutting down. The rate limit was exceeded for the ' ..
    'agent API endpoint. Contact support if you need an increased rate limit.'
    exit_code = constants:get('RATE_LIMIT_RETURN_CODE')
    timeout = constants:get('RATE_LIMIT_SLEEP')
  elseif shutdownType == constants:get('SHUTDOWN_RESTART') then
    msg = 'Attempting to restart agent'
  else
    msg = fmt('Shutdown called for unknown type %s', shutdownType)
  end

  self:_shutdown(msg, timeout, exit_code, shutdownType)
end

function Agent:getStreams()
  return self._streams
end

function Agent:disableUpgrades()
  self._upgradesEnabled = false
end

function Agent:getConfig()
  return self._config
end

function Agent:setConfig(config)
  self._config = config
end

function Agent:_preConfig(callback)
  if self._config['token'] == nil then
    logging.error("'monitoring_token' is missing from 'config'")
    process.exit(1)
  end

  -- Regen GUID
  self._config['guid'] = self:_getSystemId()

  async.series({
    -- retrieve xen id
    function(callback)
      local monitoring_id = self._config['monitoring_id']
      if monitoring_id then
        logging.infof('Using config agent ID (id=%s)', monitoring_id)
        self._config['id'] = monitoring_id
        callback()
      else
        local machid = MachineIdentity:new(self._config)
        machid:get(function(err, results)
          if err then
            logging.infof('Machine ID unobtainable, %s', err.message)
          end
          if not err and results and results.id then
            logging.infof('Using detected agent ID (id=%s)', results.id)
            self._config['id'] = results.id
          else
            logging.infof('Using hostname as agent ID (id=%s)', os.hostname())
            self._config['id'] = os.hostname()
          end
          callback()
        end)
      end
    end,
    -- log
    function(callback)
      if self._config['id'] == nil then
        logging.error("Agent ID not configured, and could not automatically detect an ID")
        process.exit(1)
      end
      logging.infof('Starting agent %s (guid=%s, version=%s, bundle_version=%s)',
                      self._config['id'],
                      self._config['guid'],
                      virgo.virgo_version,
                      virgo.bundle_version)
      callback()
    end
  }, callback)
end


function Agent:loadEndpoints(callback)
  local config = self._config
  local queries = config['query_endpoints'] or table.concat(endpoint.getEndpointSRV(), ',')
  local snetregion = config['snet_region']
  local endpoints = config['endpoints']

  local function _callback(err, endpoints)
    if err then return callback(err) end

    for _, ep in pairs(endpoints) do
      if not ep.srv_query then
        if not ep.host or not ep.port then
          logging.errorf("Invalid endpoint: %s, %s", ep.host or "", ep.port or  "")
          process.exit(1)
        end
      end
    end
    config['endpoints'] = endpoints
    callback(nil, endpoints)
  end

  if snetregion and endpoints then
    logging.errorf("Invalid configuration: snet_region and endpoints cannot be set at the same time.")
    process.exit(1)
  end

  if snetregion then
    local domains = {}

    local function matcher(v)
      return v == snetregion
    end

    if not misc.tableContains(matcher, constants:get('VALID_SNET_REGION_NAMES')) then
      logging.errorf("Invalid configuration: snet_region '%s' is not supported.", snetregion)
      process.exit(1)
    end

    logging.info(fmt('Using ServiceNet endpoints in %s region', snetregion))

    for _, address in ipairs(endpoint.getServiceNetSRV()) do
      address = address:gsub('${region}', snetregion)
      logging.debug(fmt('Endpoint SRV %s', address))
      table.insert(domains, address)
    end

    return self:_queryForEndpoints(domains, _callback)
  elseif queries and not endpoints then
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
    table.insert(new_endpoints, endpoint.Endpoint:new(address))
  end

  return _callback(nil, new_endpoints)
end

function Agent:_queryForEndpoints(domains, callback)
  local _
  local endpoints = {}
  for _, domain in pairs(domains) do
    local ep = endpoint.Endpoint:new(nil, nil, domain)
    table.insert(endpoints, ep)
  end
  callback(nil, endpoints)
end

function Agent:_getSystemId()
  local netifs = sigarCtx:netifs()
  for i=1, #netifs do
    local eth = netifs[i]:info()
    if eth['type'] ~= 'Local Loopback' then
      return UUID:new(eth.hwaddr):toString()
    end
  end
  return nil
end

function Agent:_getPersistentFilename(variable)
  return path.join(constants:get('DEFAULT_PERSISTENT_VARIABLE_PATH'), variable .. '.txt')
end

function Agent:_savePersistentVariable(variable, data, callback)
  local filename = self:_getPersistentFilename(variable)
  fsutil.mkdirp(constants:get('DEFAULT_PERSISTENT_VARIABLE_PATH'), "0755", function(err)
    if err and err.code ~= 'EEXIST' then
      callback(err)
      return
    end
    fs.writeFile(filename, data, function(err)
      callback(err, filename)
    end)
  end)
end

function Agent:_getPersistentVariable(variable, callback)
  local filename = self:_getPersistentFilename(variable)
  fs.readFile(filename, function(err, data)
    if err then
      callback(err)
      return
    end
    callback(nil, misc.trim(data))
  end)
end

return { Agent = Agent }
