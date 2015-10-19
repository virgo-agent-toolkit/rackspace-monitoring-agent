--[[
Copyright 2015 Rackspace

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
local JSON = require('json')
local timer = require('timer')
local fs = require('fs')
local los = require('los')
local table = require('table')
local fmt = require('string').format
local Emitter = require('core').Emitter

local sigar = require('sigar')
local uuid = require('virgo/util/uuid')
local async = require('async')
local spawn = require('childprocess').spawn

local Confd = require('./confd')
local ConnectionStream = require('virgo/client/connection_stream').ConnectionStream
local MachineIdentity = require('virgo/machineidentity').MachineIdentity
local constants = require('./constants')
local endpoint = require('./endpoint')
local hostname = require('./hostname')
local logging = require('logging')
local misc = require('virgo/util/misc')
local ffi = require('ffi')
local certs = require('./certs')
local isStaging = require('./staging').isStaging
local features = require('./features')

local function loadFlock()
  -- do not load on windows
  if los.type() == 'win32' then return end
  ffi.cdef[[
    int flock(int fd, int operation);
    char *strerror(int errnum);
    void free(void *ptr);
  ]]
end

loadFlock()

local Agent = Emitter:extend()
function Agent:initialize(options, types)
  self._options = options
  self._config = options.config
  self._upgradesEnabled = true
  self._types = types or {}
  self._confd = Confd:new(options.confdDir)
  self._features = features.get()
end

function Agent:start(options)
  if self:getConfig() == nil then
    return logging.error("config missing or invalid")
  end

  async.series({
    function(callback)
      self:_preConfig(callback)
    end,
    function(callback)
      self:loadEndpoints(callback)
    end,
    function(callback)
      if los.type() == 'win32' then
        return callback()
      end
      if not options.pidFile then
        options.pidFile = constants:get('DEFAULT_PID_FILE_PATH')
      end
      if not options.lockFile then
        options.lockFile = constants:get('DEFAULT_LOCK_FILE_PATH')
      end
      -- get the lock
      fs.open(options.lockFile, 'w', function(err, fd)
        if err then
          return logging.error(fmt('Agent lock file open error (path: %s): %s', options.lockFile, tostring(err)))
        end
        local rv = ffi.C.flock(fd, 6) -- LOCK_EX 2 | LOCK_NB 4
        if rv < 0 then
          local pid
          fs.close(fd)
          pcall(function()
            pid = fs.readFileSync(options.pidFile)
          end)
          return logging.error(fmt('Agent in use (pid: %s, path: %s)', tostring(pid), options.pidFile))
        end

        fs.writeFileSync(options.pidFile, tostring(process.pid))
        callback()
      end)
    end,
    function(callback)
      self._confd:setup(callback)
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

function Agent:connect(callback)
  local endpoints = self._config['endpoints']

  if #endpoints <= 0 then
    logging.error('no endpoints')
    timer.setTimeout(misc.calcJitter(constants:get('SRV_RECORD_FAILURE_DELAY'), constants:get('SRV_RECORD_FAILURE_DELAY_JITTER')), function()
      process:exit(1)
    end)
    return
  end

  logging.info(fmt('Upgrades are %s', self._upgradesEnabled and 'enabled' or 'disabled'))

  local connectionStreamType = self._types.ConnectionStream or ConnectionStream
  local codeCert = isStaging() and certs.test or certs.production
  self._streams = connectionStreamType:new(self._config['id'],
                                       self._config['token'],
                                       self._config['guid'],
                                       self._upgradesEnabled,
                                       self._options,
                                       self._types,
                                       self._features,
                                       codeCert)
  self._streams:on('error', function(err)
    logging.error(JSON.stringify(err))
  end)
  self._streams:on('upgrade.success', function()
    local shutdownType = constants:get('SHUTDOWN_UPGRADE')
    if virgo.restart_on_upgrade then
      shutdownType = constants:get('SHUTDOWN_RESTART')
    end
    self:_onShutdown(shutdownType)
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

function Agent:_restartSystemFive()
  spawn('/etc/init.d/rackspace-monitoring-agent', { 'restart' }, { detached = true })
end

function Agent:_shutdown(msg, timeout, exit_code, shutdownType)
  if shutdownType == constants:get('SHUTDOWN_RESTART') then
    self:_restartSystemFive()
  else
    -- Sleep to keep from busy restarting on upstart/systemd/etc
    timer.setTimeout(timeout, function()
      if msg then logging.info(msg) end
      process:exit(exit_code)
    end)
  end
end

function Agent:disconnect()
  self._streams:shutdown()
end

function Agent:_onShutdown(shutdownType)
  local timeout = 0
  local exit_code = 0
  local msg

  self:disconnect()

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
    return logging.error("'monitoring_token' is missing from 'config'")
  end

  -- Regen GUID
  self._config['guid'] = self:_getSystemId()
  self._config['token'] = misc.trim(self._config['token'])
  self._config['id'] = misc.trim(self._config['id'])

  -- Disable Features
  features.disableWithOption(self._config['upgrade'], 'upgrades', true)
  features.disableWithOption(self._config['health'], 'health')

  -- Set Feature Params
  features.setParams('poller', {
    private_zone = self._config['private_zone']
  })

  self._features = features.get()

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
            self._config['id'] = hostname()
            logging.infof('Using hostname as agent ID (id=%s)', self._config['id'])
          end
          callback()
        end)
      end
    end,
    -- log
    function(callback)
      if self._config['id'] == nil then
        return logging.error("Agent ID not configured, and could not automatically detect an ID")
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
  local queries = config['query_endpoints']
  local snetregion = config['snet_region']
  local endpoints = config['endpoints']

  local function _callback(err, endpoints)
    if err then return callback(err) end

    for _, ep in pairs(endpoints) do
      if not ep.srv_query then
        if not ep.host or not ep.port then
          return logging.errorf("Invalid endpoint: %s, %s", ep.host or "", ep.port or  "")
        end
      end
    end
    config['endpoints'] = endpoints
    callback(nil, endpoints)
  end

  if not (snetregion or endpoints or queries) then
    queries = table.concat(endpoint.getEndpointSRV(), ',')
  end

  if (snetregion and queries) or (snetregion and endpoints) or (queries and endpoints) then
    return logging.errorf("Invalid configuration: only one of snet_region, queries, and endpoints can be set.")
  end

  if snetregion then
    local domains = {}

    local function matcher(v)
      return v == snetregion
    end

    if not misc.tableContains(matcher, constants:get('VALID_SNET_REGION_NAMES')) then
      return logging.errorf("Invalid configuration: snet_region '%s' is not supported.", snetregion)
    end

    logging.info(fmt('Using ServiceNet endpoints in %s region', snetregion))

    for _, address in ipairs(endpoint.getServiceNetSRV()) do
      address = address:gsub('${region}', snetregion)
      logging.debug(fmt('Endpoint SRV %s', address))
      table.insert(domains, address)
    end

    return self:_queryForEndpoints(domains, _callback)
  end

  if queries then
    local domains = misc.split(queries, '[^,]+')
    return self:_queryForEndpoints(domains, _callback)
  end

  -- It's neither `snetregion` nor `queries`, has to be `endpoints`.

  -- split address,address,address
  endpoints = misc.split(endpoints, '[^,]+')

  if #endpoints == 0 then
    return logging.error("at least one endpoint needs to be specified")
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
  local netifs = sigar:new():netifs()
  for i=1, #netifs do
    local eth = netifs[i]:info()
    if eth['type'] ~= 'Local Loopback' then
      return uuid:new(eth.hwaddr):toString()
    end
  end
  return nil
end

return { Agent = Agent }
