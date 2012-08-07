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
local JSON = require('json')
local Object = require('core').Object
local string = require('string')
local fmt = require('string').format
local https = require('https')
local url = require('url')
local table = require('table')
local Error = require('core').Error

local async = require('async')

local misc = require('./misc')
local errors = require('./errors')

local KeystoneClient = require('keystone').Client

local MAAS_CLIENT_KEYSTONE_URL
local MAAS_CLIENT_DEFAULT_HOST
local MAAS_CLIENT_DEFAULT_VERSION

if process.env.STAGING then
  MAAS_CLIENT_KEYSTONE_URL = 'https://staging.identity.api.rackspacecloud.com/v2.0'
  MAAS_CLIENT_DEFAULT_HOST = 'staging.monitoring.api.rackspacecloud.com'
  MAAS_CLIENT_DEFAULT_VERSION = 'v1.0'
else
  MAAS_CLIENT_KEYSTONE_URL = 'https://identity.api.rackspacecloud.com/v2.0'
  MAAS_CLIENT_DEFAULT_HOST = 'monitoring.api.rackspacecloud.com'
  MAAS_CLIENT_DEFAULT_VERSION = 'v1.0'
end

--[[ ClientBase ]]--

local ClientBase = Object:extend()
function ClientBase:initialize(host, port, version, apiType, options)
  local headers = {}

  self.host = host
  self.port = port
  self.version = version
  self.apiType = apiType
  self.tenantId = nil

  if self.apiType == 'public' then
    headers['User-Agent'] = 'agent/virgo'
  end

  self.headers = headers
  self.options = misc.merge({}, options)

  self.headers['Accept'] = 'application/json'
  self.headers['Content-Type'] = 'application/json'
end

function ClientBase:setToken(token, expiry)
  self.token = token
  self.headers['X-Auth-Token'] = token
  self._tokenExpiry = expiry
end

function ClientBase:setTenantId(tenantId)
  self.tenantId = tenantId
end

function ClientBase:_parseResponse(data, callback)
  local parsed = JSON.parse(data)
  callback(nil, parsed)
end

function ClientBase:_parseData(data)
  local res = {
    xpcall(function()
      return JSON.parse(data)
    end, function(e)
      return e
    end)
  }
  if res[1] == false then
    return res[2]
  else
    return JSON.parse(res[2])
  end
end

function ClientBase:request(method, path, payload, expectedStatusCode, callback)
  local options
  local headers
  local extraHeaders = {}

  -- setup payload
  if payload then
    if type(payload) == 'table' and self.headers['Content-Type'] == 'application/json' then
      payload = JSON.stringify(payload)
    end
    extraHeaders['Content-Length'] = #payload
  else
    extraHeaders['Content-Length'] = 0
  end

  -- setup path
  if self.tenantId then
    path = fmt('/%s/%s%s', self.version, self.tenantId, path)
  else
    path = fmt('/%s%s', self.version, path)
  end

  headers = misc.merge(self.headers, extraHeaders)

  options = {
    host = self.host,
    port = self.port,
    path = path,
    headers = headers,
    method = method
  }

  local req = https.request(options, function(res)
    local data = ''
    res:on('data', function(chunk)
      data = data .. chunk
    end)
    res:on('end', function()
      self._lastRes = res
      if res.statusCode ~= expectedStatusCode then
        callback(errors.HttpResponseError:new(res.statusCode, method, path, data))
      else
        if res.statusCode == 200 then
          self:_parseResponse(data, callback)
        elseif res.statusCode == 201 or res.statusCode == 204 then
          callback(nil, res.headers['location'])
        else
          data = self:_parseData(data)
          callback(errors.HttpResponseError:new(res.statusCode, method, path, data))
        end
      end
    end)
  end)
  if payload then
    req:write(payload)
  end
  req:done()
end

--[[ Client ]]--

local Client = ClientBase:extend()
function Client:initialize(userId, key, options)
  options = options or {}
  self.userId = userId
  self.key = key
  self.authUrl = options.authUrl
  self.entities = {}
  self.agent_tokens = {}
  self:_init()
  ClientBase.initialize(self, MAAS_CLIENT_DEFAULT_HOST, 443,
                        MAAS_CLIENT_DEFAULT_VERSION, 'public', options)
end

function Client:_init()
  self.entities.get = function(callback)
    self:request('GET', '/entities', nil, 200, callback)
  end

  self.agent_tokens.get = function(callback)
    self:request('GET', '/agent_tokens', nil, 200, callback)
  end

  self.agent_tokens.create = function(options, callback)
    local body = {}
    body['label'] = options.label
    self:request('POST', '/agent_tokens', body, 201, function(err, tokenUrl)
      if err then
        callback(err)
        return
      end
      callback(nil, string.match(tokenUrl, 'agent_tokens/(.*)'))
    end)
  end
end

function Client:auth(authUrl, username, keyOrPassword, callback)
  local apiKeyClient = KeystoneClient:new(authUrl, { username = self.userId, apikey = keyOrPassword })
  local passwordClient = KeystoneClient:new(authUrl, { username = self.userId, password = keyOrPassword })
  local errors = {}
  local responses = {}

  function iterator(client, callback)
    client:tenantIdAndToken(function(err, obj)
      if err then
        table.insert(errors, err)
        callback()
      else
        table.insert(responses, obj)
        callback()
      end
    end)
  end

  async.forEach({ apiKeyClient, passwordClient }, iterator, function()
    if #responses > 0 then
      callback(nil, responses[1])
    else
      callback(errors)
    end
  end)
end

--[[
The request.
callback.function(err, results)
]]--
function Client:request(method, path, payload, expectedStatusCode, callback)
  local authUrl = self.authUrl or MAAS_CLIENT_KEYSTONE_URL
  local authPayload
  local results

  async.waterfall({
    function(callback)
      if self:tokenValid() then
        callback()
        return
      end
      self:auth(authUrl, self.userId, self.key, function(err, obj)
        if err then
          callback(err)
          return
        end
        self:setToken(obj.token, obj.expires)
        self:setTenantId(obj.tenantId)
        callback()
      end)
    end,

    function(callback)
      ClientBase.request(self, method, path, payload, expectedStatusCode, function(err, obj)
        if not err then
          results = obj
        end
        callback(err)
      end)
    end
  }, function(err)
    callback(err, results)
  end)
end

function Client:tokenValid()
  if self.token then
    return true
  end

  -- TODO add support for expiry

  return nil
end

local exports = {}
exports.Client = Client
return exports
