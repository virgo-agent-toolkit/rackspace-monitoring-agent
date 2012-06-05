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

local async = require('async')
local logging = require('logging')

local router = require('./lib/http/router')
local urls = require('./lib/api/urls').urls

function Collector:initialize(options)
  self._host = options.host or '127.0.0.1'
  self._port = options.port or 8080

  self._apiServer = nil
  self._router = router.getRouter(urls)
end

function Collector:_startApiServer(callback)
  self._apiServer = http.createServer(function(req, res)
    self._handleRequest(req, res)
  end)

  self._apiServer:listen(self._port)
  callback()
end

function Collector:_handleRequest(req, res)
  self.router:route(req, res)
end

function Collector:run(options)
  async.series({
    function()
      self:_startApiServer(callback)
    end
  }, calllback)
end

function Collector.run(options)
  local collector = Collector:new(options)

  collector:run(function(err)
    if err then
      logging.log(logging.ERR, err.message)
    end
  end)
end

return Collector
