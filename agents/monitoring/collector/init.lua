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
local http = require('http')
local fmt = require('string').format

local async = require('async')
local logging = require('logging')

local router = require('./http/router')
local urls = require('./api/urls').urls

local Collector = Object:extend()

function Collector:initialize(options)
  self._host = options.host and options.host or '127.0.0.1'
  self._port = options.port and options.port or 8080

  self._apiServer = nil
  self._router = router.getRouter(urls)
end

function Collector:_startApiServer(callback)
  self._apiServer = http.createServer(function(req, res)
    self:_handleRequest(req, res)
  end)

  self._apiServer:listen(self._port, self._host, function(err)
    if err then
      callback(err)
      return
    end

    logging.log(logging.INFO, fmt('HTTP server listening on %s:%s',
                                  self._host, self._port))
    callback()
  end)
end

function Collector:_handleRequest(req, res)
  self._router(req, res)
end

function Collector:start(callback)
  async.series({
    function(callback)
      self:_startApiServer(callback)
    end
  }, callback)
end

function Collector:stop(callback)
  callback = callback and callback or function() end
  logging.log(logging.DEBUG, 'Stopping collector...')
  self._apiServer:close()
  callback()
end

function Collector.run(argv)
  argv = argv and argv or {}
  local options = {}

  if argv.p then
    options.port = argv.p
  end

  if argv.h then
    options.host = argv.h
  end

  local collector = Collector:new(options)

  collector:start(function(err)
    if err then
      logging.log(logging.ERR, err.message)
    end
  end)

  return collector
end

return Collector
