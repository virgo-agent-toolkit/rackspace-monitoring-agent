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

local native = require('uv_native')
local os = require('os')
local Object = require('core').Object
local fmt = require('string').format
local fs = require('fs')
local timer = require('timer')
local JSON = require('json')
local table = require('table')

local async = require('async')
local ask = require('./util/prompt').ask
local errors = require('./errors')
local constants = require('./util/constants')
local sigarCtx = require('./sigar').ctx

local maas = require('rackspace-monitoring')

local Setup = Object:extend()
function Setup:initialize(argv, configFile, agent)
  self._configFile = configFile
  self._agent = agent
  self._receivedPromotion = false
  self._username = argv.U
  self._apikey = argv.K
  self._agent:on('promote', function()
    self._receivedPromotion = true
  end)
  self._addresses = {}

  -- build a "set" (table keyed by address) of local IP addresses
  local netifs = sigarCtx:netifs()

  for i=1,#netifs do
    local info = netifs[i]:info()
    if info['address'] then
      self._addresses[info['address']] = true
    end
    if info['addres6'] then
      self._addresses[info['address6']] = true
    end
  end
end

function Setup:saveTest(callback)
  fs.open(self._configFile, 'a', "0644", function(err)
    if err then
      process.stdout:write(fmt('Error: cannot open config file: %s\n', self._configFile))
      callback(err)
      return
    end
    callback()
  end)
end

function Setup:save(token, hostname, callback)
  process.stdout:write(fmt('Writing token to %s: ', self._configFile))
  local data = fmt('monitoring_token %s\n', token)
  data = data .. fmt('monitoring_id %s\n', hostname)

  --[[
  1. We are using an environment variable because we thought adding special hidden
  command line arguments logic may make it too complex.

  2. this feature will be ran by such a small set of people who are very
  technically minded anyways so setting an environment variable is OK.
  ]]--
  fs.writeFile(self._configFile, data, function(err)
    if err then
      process.stdout:write('failed writing config filen\n')
      callback(err)
      return
    end
    process.stdout:write('done\n')
    callback()
  end)
end

function Setup:_out(msg)
  process.stdout:write(msg .. '\n')
end

function Setup:_getOsStartString()
  return 'service rackspace-monitoring-agent start'
end

function Setup:_isLocalEntity(entity)
  if entity.label == os.hostname() then
    return true
  end

  if entity.ip_addresses then
    for k, address in pairs(entity.ip_addresses) do
      -- TODO: we should really translate all v6 addresses to a standard form
      -- for this comparison, currently there is a good chance of us missing a
      -- v6 match
      if self._addresses[address] then
        return true
      end
    end
  end

  return false
end

function Setup:_buildLocalEntity(agentId)
  local addresses = {}
  local netifs = sigarCtx:netifs()

  for i=1,#netifs do
    local info = netifs[i]:info()
    if info.type ~= 'Local Loopback' then
      if info['address'] then
        addresses[info['name'] .. '_v4'] = info['address']
      end
      if info['addres6'] then
        addresses[info['name'] .. '_v6'] = info['address6']
      end
    end
  end

  return {
    label = agentId,
    agent_id = agentId,
    ip_addresses = addresses
  }
end

function Setup:run(callback)
  local username, token, hostname
  local agentToken, client

  hostname = os.hostname()
  self:_out('')
  self:_out('Setup Settings:')
  self:_out(fmt('  Hostname: %s', hostname))
  self:_out(fmt('  Config File: %s', self._configFile))
  self:_out(fmt('  State Directory: %s', self._agent._stateDirectory))
  self:_out('')

  function createToken(callback)
    client.agent_tokens.create({ ['label'] = hostname }, function(err, token)
      if err then
        callback(err)
        return
      end
      self._agent:setConfig({ ['monitoring_token'] = token })
      self:save(token, hostname, callback)
    end)
  end

  async.waterfall({
    function(callback)
      self:saveTest(callback)
    end,
    function(callback)
      if (self._username == nil and self._apikey ~= nil)
         or (self._username ~= nil and self._apikey == nil) then
        callback(errors.UserResponseError:new('Username and password/apikey must be provided together.'))
      else
        callback()
      end
    end,
    function(callback)
      if self._username == nil then
        ask('Username:', callback)
      else
        callback(nil, self._username)
      end
    end,
    function(_username, callback)
      if self._apikey == nil then
        ask('API Key or Password:', function(err, _token)
          username = _username
          token = _token
          callback(err, username, token)
        end)
      else
        callback(nil, self._username, self._apikey)
      end
    end,
    -- fetch all tokens
    function(username, token, callback)
      client = maas.Client:new(username, token)
      client.agent_tokens.get(callback)
    end,
    -- is there a token for the host
    function(tokens, callback)
      for i, v in ipairs(tokens.values) do
        if v.label and v.label == hostname then
          agentToken = v.token
          break
        end
      end
      callback(nil, agentToken, tokens)
    end,
    function(agentToken, tokens, callback)
      -- save the token if we found it
      if agentToken then
        self:_out('')
        self:_out(fmt('Found existing Agent Token for %s', hostname))
        self:_out('')
        self._agent:setConfig({ ['monitoring_token'] = agentToken })
        self:save(agentToken, hostname, callback)
        -- display a list of tokens
      elseif self._username and self._apikey then
         createToken(callback)
      elseif #tokens.values > 0 then
        self:_out('')
        self:_out('The Monitoring Agent uses an authentication token to communicate with the Cloud Monitoring Service.')
        self:_out('')
        self:_out('Please select from an existing token, or create a new token:')
        for i, v in ipairs(tokens.values) do
          if v.label then
            self:_out(fmt('  %i. %s - %s', i, v.label, v.id))
          else
            self:_out(fmt('  %i. %s', i, v.id))
          end
        end
        self:_out(fmt('  %i. Create New Token', #tokens.values + 1))
        self:_out('')

        ask('Select Option:', function(err, index)
          if err then
            callback(err)
            return
          end
          self:_out('')
          local validatedIndex = tonumber(index) -- validate response
          if validatedIndex >= 1 and validatedIndex <= #tokens.values then
            self._agent:setConfig({ ['monitoring_token'] = tokens.values[validatedIndex].id })
            self:save(tokens.values[validatedIndex].id, hostname, callback)
          elseif validatedIndex == (#tokens.values + 1) then
            createToken(callback)
          else
            callback(errors.UserResponseError:new('User input is not valid. Expected integer.'))
          end
        end)
        -- create a token and save it
      else
        createToken(callback)
      end
    end,
    -- test connectivity
    function(callback)
      self:_out('')
      self:_out('Testing Agent connectivity to Cloud Monitoring Service...')
      self:_out('')
      async.series({
        function(callback)
          self._agent:loadEndpoints(callback)
        end,
        function(callback)
          self._agent:loadStates(callback)
        end,
        function(callback)
          self._agent:connect()
          callback()
        end,
        function(callback)
          function timeout()
            callback(errors.AuthTimeoutError:new('Authentication timed out.'))
          end

          local authTimer = timer.setTimeout(constants.SETUP_AUTH_TIMEOUT, timeout)

          function testAuth()
            timer.clearTimer(authTimer)
            if self._receivedPromotion then
              self:_out('')
              self:_out('Agent successfuly connected!')
              callback()
            else
              authTimer = timer.setTimeout(constants.SETUP_AUTH_TIMEOUT, timeout)
              timer.setTimeout(constants.SETUP_AUTH_CHECK_INTERVAL, testAuth)
            end
          end

          timer.setTimeout(constants.SETUP_AUTH_CHECK_INTERVAL, testAuth)
        end
      }, callback)
    end,

    -- Bind to an entity
    function(connections, callback)
      self:_out('')
      self:_out('In order to execute checks, the agent must be bound to a Cloud Monitoring Entity.')
      self:_out('')
      async.waterfall({
        function(callback)
          client.entities.list(callback)
        end,
        function(entities, callback)
          local addresses = {}
          local localEntities = {}

          for i, entity in ipairs(entities.values) do
            if self:_isLocalEntity(entity) then
              table.insert(localEntities, entity)
            end
            if (entity.agent_id == hostname) then
              self:_out(fmt('Agent already bound to entity with id=%s and label=%s', entity.id, entity.label))
              callback(nil)
            end
          end

          self:_out('Please select the Entity that corresponds to this server:')

          for i, entity in ipairs(localEntities) do
            if entity.label then
              self:_out(fmt('  %i. %s - %s', i, entity.label, entity.id))
            else
              self:_out(fmt('  %i. %s', i, entity.id))
            end
            if entity.ip_addresses then
              for k, address in pairs(entity.ip_addresses) do
                self:_out(fmt('       %s: %s', k, address))
              end
            end
          end

          self:_out(fmt('  %i. Create an new entity for this server (not supported by Rackspace Cloud Control Panel)', #localEntities + 1))
          self:_out('')

          ask('Select Option (e.g., 1):', function(err, index)
            if err then
              callback(err)
              return
            end

            local validatedIndex = tonumber(index)
            if validatedIndex == #localEntities + 1 then
              client.entities.create(self:_buildLocalEntity(hostname), callback)
            elseif validatedIndex >= 1 and validatedIndex <= #localEntities then
              client.entities.update(localEntities[validatedIndex].id, { agent_id = hostname }, callback)
            else
              self:_out('Invalid selection')
              callback()
            end
          end)
        end
      }, callback)
    end
  }, function(err)
    if err then
      local msg = nil
      if type(err) == 'string' then
        msg = err
      elseif err.message then
        msg = err.message
      elseif err.data then
        pcall(function() msg = JSON.parse(err.data).message end)
      end
      if not msg then
        msg = JSON.stringify(err)
      end
      process.stdout:write(fmt('Error: %s\n', msg))
    else
      -- TODO: detect Platform, iniit.d system, etc
      self:_out('')
      self:_out('Your Agent configuration is now complete.')
      self:_out('')
      self:_out('To start the Agent on your server, now run:')
      self:_out('')
      self:_out(fmt('    %s', self:_getOsStartString()))
      self:_out('')
      self:_out('')
    end
    process.exit(0)
  end)

end

local exports = {}
exports.Setup = Setup
return exports
