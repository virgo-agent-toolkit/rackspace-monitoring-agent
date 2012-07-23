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
local Error = require('core').Error
local https = require('https')
local table = require('table')
local fmt = require('string').format
local url = require('url')

local Client = Object:extend()
function Client:initialize(authUrl, options)
  self.authUrl = authUrl
  self.username = options.username
  self.apikey = options.apikey
  self.password = options.password
  self.extraArgs = options.extraArgs or {}
  self._token = nil
  self._tokenExpires = nil
  self._tenantId = nil
  self._serviceCatalog = {}

end

function Client:_updateToken(callback)
  local body = {}
  local parsed = url.parse(self.authUrl)
  local urlPath
  local options
  local headers
  local client
  local body

  headers = {}
  headers['Accept'] = 'application/json'
  headers['Content-Type'] = 'application/json'

  urlPath = fmt('%s/tokens', parsed.pathname)

  if self.password then
    body = {
      ['auth'] = {
        ['passwordCredentials'] = {
          ['username'] = self.username,
          ['password'] = self.password
        }
      }
    }
  else
    body = {
      ['auth'] = {
        ['RAX-KSKEY:apiKeyCredentials'] = {
          ['username'] = self.username,
          ['apiKey'] = self.apikey
        }
      }
    }
  end

  body = JSON.stringify(body)
  headers['Content-Length'] = #body

  options = {
    host = parsed.hostname,
    port = tonumber(parsed.port),
    path = urlPath,
    headers = headers,
    method = 'POST'
  }

  client = https.request(options, function(res)
    local data = ''
    res:on('data', function(chunk)
      data = data .. chunk
    end)
    res:on('end', function()
      local json, payload, newToken, newExpires
      local results  = {
        xpcall(function()
          return JSON.parse(data)
        end, function(err)
          return err
        end)
      }
      -- protected call errored out
      if not results[1] then
        callback(results[1])
        return
      end
      payload = results[2]

      if payload.access then
        newToken = payload.access.token.id
        newExpires = payload.access.token.expires
      else
        callback(Error:new('Invalid response from auth server'))
        return
      end

      self._token = newToken
      self._tokenExpires = newExpires
      self._serviceCatalog = payload.access.serviceCatalog

      callback(nil, self._token)
    end)
  end)
  client:done(body)
end

function Client:tenantIdAndToken(callback)
  self:_updateToken(function(err, token)
    if err then
      callback(err)
      return
    end
    for i, _ in ipairs(self._serviceCatalog) do
      local item = self._serviceCatalog[i]
      if item.name == 'cloudServers' or item.name == 'cloudServersLegacy' then
        if #item.endpoints == 0 then
          error('Endpoints should be > 0')
        end
        self._tenantId = item.endpoints[1].tenantId
      end
    end
    callback(nil, { token = self._token, expires = self._tokenExpires, tenantId = self._tenantId })
  end)
end

local exports = {}
exports.Client = Client
return exports
