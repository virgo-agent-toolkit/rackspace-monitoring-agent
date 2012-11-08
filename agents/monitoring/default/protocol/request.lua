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

local table = require('table')
local https = require('https')
local fs = require('fs')

local logging = require('logging')
local errors = require('../errors')
local Error = require('core').Error
local misc = require('../util/misc')

local fmt = require('string').format
local Object = require('core').Object

local exports = {}

local Request = Object:extend()

--[[
  options = {
    host/port OR endpoints [{Endpoint1, Endpoint2, ...}]
    path = "string",
    method = "METHOD"
    upload = nil or '/some/path'
    download = nil or '/some/path'
    attempts = "INT" or #endpoints
  }
]]--

local function makeRequest(...)
  local req = Request:new(...)
  req:set_headers()
  req:request()
  return req
end

function Request:initialize(options, callback)
  self.callback = misc.fireOnce(callback)

  if not options.method then
    return self.callback(Error:new('I need a http method'))
  end

  if options.endpoints then
    self.endpoints = misc.merge({}, options.endpoints)
  else
    self.endpoints = {{host=options.host, port=options.port}}
  end
  self.attempts = options.attempts or #self.endpoints
  self.download = options.download
  self.upload = options.upload

  options.endpoints = nil;
  options.attempts = nil
  options.download = nil
  options.upload = nil

  self.options = options

  if not self:_cycle_endpoint() then
    return self.callback(Error:new('call with options.port and options.host or options.endpoints'))
  end
end

function Request:request()
  logging.debug('sending request to '..self.options.host..':'.. self.options.port)

  local options = misc.merge({}, self.options)

  local req = https.request(options, function(res)
    self:_handle_response(res)
  end)

  req:on('error', function(err)
    self:_ensure_retries(err)
  end)

  if not self.upload then
    return req:done()
  end

  local data = fs.createReadStream(self.upload)
  data:on('data', function(chunk)
    req:write(chunk)
  end)
  data:on('end', function(d)
    req:done(d)
  end)
  data:on('error', function(err)
    req:done()
    self._ensure_retries(err)
  end)
end

function Request:_cycle_endpoint()
  local position, endpoint

  while self.attempts > 0 do
    position = #self.endpoints % self.attempts
    endpoint = self.endpoints[position+1]
    self.attempts = self.attempts - 1
    if endpoint and endpoint.host and endpoint.port then
      self.options.host = endpoint.host
      self.options.port = endpoint.port
      return true
    end
  end

  return false
end

function Request:set_headers(callback)
  local method = self.options.method:upper()
  local headers = {}

  -- set defaults
  headers['Content-Length'] = 0
  headers["Content-Type"] = "application/text"
  self.options.headers = misc.merge(headers, self.options.headers)
end

function Request:_write_stream(res)
  logging.debug('writing stream to disk: '.. self.download)

  local stream = fs.createWriteStream(self.download)

  stream:on('end', function()
    self:_ensure_retries(nil, res)
  end)

  stream:on('error', function(err)
    self:_ensure_retries(err, res)
  end)

  res:on('end', function(d)
    stream:finish(d)
  end)

  res:pipe(stream)
end

function Request:_ensure_retries(err, res)
  if not err then
    return self.callback(err, res)
  end

  local status = res and res.status_code or "?"

  local msg = fmt('%s to %s:%s failed for %s with status: %s and error: %s.', (self.options.method or "?"),
              self.options.host, self.options.port, (self.download or self.upload or "?"), status, tostring(err))

  logging.warn(msg)

  logging.debug('retrying download '.. self.attempts .. ' more times.')

  if not self:_cycle_endpoint() then
    return self.callback(err)
  end

  self:request()
end

function Request:_handle_response(res)
  logging.debug('res')

  if self.download then
    return self:_write_stream(res)
  end

  local buf = ""
  res:on('data', function(d)
    buf = buf .. d
  end)

  res:on('end', function()
    if res.status_code >= 400 then
      return self:_ensure_retries(Error:new(buf), res)
    end

    self:_ensure_retries(nil, res)
  end)
end

local exports = {makeRequest=makeRequest, Request=Request}

return exports
