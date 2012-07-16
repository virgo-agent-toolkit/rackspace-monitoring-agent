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

local Object = require('core').Object
local logging = require('logging')
local https = require('https')
local url = require('url')
local fs = require('fs')

local CrashReportSubmitter = Object:extend()

function CrashReportSubmitter:initialize(filename, url)
  self._path = filename
  self._url = url
end

function CrashReportSubmitter:run(callback)
  local headers = {}
  local parsed = url.parse(self._url)

  logging.infof('Uploading %s to %s', self._path, self._url)

  headers = {}
  headers['Content-Type'] = 'application/octet-stream'

  local options = {
    host = parsed.hostname,
    port = tonumber(parsed.port),
    path = parsed.pathname,
    headers = headers,
    method = 'POST'
  }

  client = https.request(options, function(res)
    local data = ''
    res:on('data', function(chunk)
      data = data .. chunk
    end)
    res:on('end', function()
      callback()
    end)
  end)

  client:on('error', function(err)
    logging.info('Failed to upload crash report: %s', err)
    p(err)
    callback(err)
  end)

  local stream = fs.createReadStream(self._path)
  stream:on('data', function(chunk)
    client:write(chunk)
  end)

  stream:on('error', function(err)
    logging.info('Failed to upload crash report: %s', err)
    client:done()
    callback(err)
  end)

  stream:on('close', function()
    client:done()
    callback(err)
  end)
end

local exports = {}
exports.CrashReportSubmitter = CrashReportSubmitter
return exports

