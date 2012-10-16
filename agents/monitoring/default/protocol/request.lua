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
local misc = require('../util/misc')

local fmt = require('string').format
local Object = require('core').Object

local exports = {}

local Request = Object:extend()

function makeRequest(...)
  return Request:new(...):request()
end

function Request:initialize(options, download_path, upload_path, callback, retries)
  callback = misc.fireOnce(callback)

  if not options.method then
    return callback(errors.Error('I need a http method'))
  end

  -- endpoints are ip:port - we normally have multiples and its stupid to put this logic everywhere
  self.options = options
  retries = retries or self:set_host_and_port() or 3

  if not options.host or not options.port then
    return callback(errors.Error('call with options.port and options.host or options.monitoring_endpoints'))
  end

  self.download_path = download_path
  self.upload_path = upload_path
  self.retries = retries
  self.callback = callback
  self.headers_set = false
end

function Request:set_host_and_port()
  -- endpoints are ip:port - we normally have multiples
  -- grab one- set retries to the remaining number
  -- get a host if multiples were passed in
  local retries, address

  if not self.options.monitoring_endpoints or 
    #self.options.monitoring_endpoints < 1 then
    return
  end

  retries = #self.options.monitoring_endpoints
  address = table.remove(self.options.monitoring_endpoints)
  self.options.host = address[0]
  self.options.port = address[1]

  return retries

end

function Request:_set_headers(callback)
  local method = self.options.method:upper()
  local headers = {}

  local _callback = function(...)
    -- merge the headers into our options
    self.options.headers = misc.merge(headers, self.options.headers)
    self.headers_set = true
    callback(...)
  end

  -- set defaults
  headers['Content-Length'] = 0
  headers["Content-Type"] = "application/text"
  if method == 'GET' or not self.upload_path then
    return _callback()
  end

  -- set type on anything not a GET (including DELETE)
  fs.stat(self.upload_path, function(err, stats)
    if err then 
      logging.error("couldn't stat file: " .. self.upload_path .. ' because ' .. tostring(err))
      return _callback(err)
    end
    headers["Content-Type"] = "application/octet-stream"
    headers['Content-Length'] = stats.size
    return _callback()
  end)
end

function Request:write_stream(res)
  loggind.debug('writing stream to disk: '.. self.download_path)

  local stream = fs.createWriteStream(self.download_path)

  stream:on('end', function()
    self:ensure_retries(nil, res)
  end)

  stream:on('error', function(err)
    self:ensure_retries(err, res)
  end)

  res:on('end', function(d)
    stream:finish(d)
  end)

  res:pipe(stream)
end

function Request:ensure_retries(err, res)
  if not err then
    return self.callback(err, res)
  end
  
  local status = res and res.status_code or "?"
  
  local msg = fmt('%s request failed for %s with status: %s and error: %s', self.options.method or "?", 
              self.download_path or self.upload_path or "?", status, tostring(err))

  logging.warn(msg)

  if self.retries > 0 then
    self.retries = self.retries - 1
    logging.debug('retrying download '.. self.retries .. ' more times.')

    -- try a different data center if possible
    self:set_host_and_port()
    return self:request()
  end
  
  self.callback(err)
end

function Request:handle_response(res)
  logging.debug('res')

  if res.status_code >= 400 then
    return self:ensure_retries(errors.Error:new("bad status"), res)
  end

  if self.download_path then
    return self:write_stream(res)
  end

  local buf = ""
  res:on('data', function(d)
    buf = buf .. d
  end)

  res:on('end', function()
    logging.debug('got response: ' .. buf)
    self:ensure_retries(nil, res)
  end)
end

function Request:request()
  if not self.headers_set then
    return self:_set_headers(function(err)
      if err then
        return self.callback(err)
      end
      self:request()
    end)
  end

  logging.debug('sending request')

  local req = https.request(self.options, function(res) 
    self:handle_response(res) 
  end)

  req:on('error', function(err)
    ensure_retries(err)
  end)

  if not self.upload_path then
    return req:done()
  end

  local data = fs.createReadStream(self.upload_path)
  data:on('data', function(d)
    req:write(d)
  end)
  data:on('end', function(d)
    req:done(d)
  end)
  data:on('error', function(err)
    req:done()
    self.callback(err)
  end)
end

return makeRequest