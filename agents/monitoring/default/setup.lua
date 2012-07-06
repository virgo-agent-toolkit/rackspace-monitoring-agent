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

local async = require('async')
local ask = require('./util/prompt').ask
local errors = require('./errors')
local constants = require('./util/constants')

local maas = require('rackspace-monitoring')

local Setup = Object:extend()
function Setup:initialize(configFile, agent)
  self._configFile = configFile
  self._agent = agent
  self._receivedPromotion = false
  self._agent:on('promote', function()
    self._receivedPromotion = true
  end)
end

function Setup:save(token, hostname, callback)
  if self._configFile then
    process.stdout:write(fmt('Writing token to %s: ', self._configFile))
    local data = fmt('monitoring_token %s\n', token)
    data = data .. fmt('monitoring_id %s\n', hostname)
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
end

function Setup:run(callback)
  local username, token, hostname
  local agentToken, client

  hostname = os.hostname()
  process.stdout:write(fmt('Using hostname \'%s\'\n', hostname))

  async.waterfall({
    function(callback)
      ask('What is your Rackspace cloud username:', callback)
    end,
    function(_username, callback)
      ask('What is your Rackspace API key or Password:', function(err, _token)
        username = _username
        token = _token
        callback(err, username, token)
      end)
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
        process.stdout:write('Found agent token for host\n')
        self._agent:setConfig({ ['monitoring_token'] = agentToken })
        self:save(agentToken, hostname, callback)
        -- display a list of tokens
      elseif #tokens.values > 0 then
        process.stdout:write('\n')
        process.stdout:write('Tokens:\n')
        for i, v in ipairs(tokens.values) do
          if v.label then
            process.stdout:write(fmt('  %i. %s - %s\n', i, v.label, v.id))
          else
            process.stdout:write(fmt('  %i. %s\n', i, v.id))
          end
        end
        process.stdout:write('\n')
        ask('  Select Token:', function(err, index)
          if err then
            callback(err)
            return
          end
          process.stdout:write('\n')
          local validatedIndex = tonumber(index) -- validate response
          if validatedIndex >= 1 and validatedIndex <= #tokens.values then
            self._agent:setConfig({ ['monitoring_token'] = tokens.values[validatedIndex].id })
            self:save(tokens.values[validatedIndex].id, hostname, callback)
          else
            callback(errors.UserResponseError:new('User input is not valid. Expected integer.'))
          end
        end)
        -- create a token and save it
      else
        client.agent_tokens.create({ ['label'] = hostname }, function(err, token)
          if err then
            callback(err)
            return
          end
          self._agent:setConfig({ ['monitoring_token'] = token })
          self:save(token, hostname, callback)
        end)
      end
    end,
    -- test connectivity
    function(callback)
      process.stdout:write('Testing agent connection...\n')
      async.series({
        function(callback)
          self._agent:loadStates(callback)
        end,
        function(callback)
          self._agent:connect()
          callback()
        end,
        function(callback)
          function timeout()
            callback(errors.AuthTimeoutError:new('Failed to authenticate. Please contact support'))
          end

          local authTimer = timer.setTimeout(constants.SETUP_AUTH_TIMEOUT, timeout)

          function testAuth()
            timer.clearTimer(authTimer)
            if self._receivedPromotion then
              callback()
            else
              authTimer = timer.setTimeout(constants.SETUP_AUTH_TIMEOUT, timeout)
              timer.setTimeout(constants.SETUP_CHECK_AUTH_INTERVAL, testAuth)
            end
          end

          timer.setTimeout(constants.SETUP_AUTH_CHECK_INTERVAL, testAuth)
        end,
        function(callback)
          process.stdout:write('\n\nSuccessfully tested Agent connection\n')
          process.stdout:write('\nYour agent is ready to go, now run:\n')
          process.stdout:write('\n    service rackspace-monitoring-agent start\n\n')
          callback()
        end
      }, callback)
    end
  }, function(err)
    if err then
      if type(err) == 'string' then
        process.stdout:write(fmt('Error: %s\n', err))
      elseif err.message then
        process.stdout:write(fmt('Error: %s\n', err.message))
      else
        process.stdout:write(fmt('Error: %s\n', JSON.stringify(err)))
      end
    end
    process.exit(0)
  end)

end

local exports = {}
exports.Setup = Setup
return exports
