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

local string = require('string')
local fmt = require('string').format
local url = require('url')

local logging = require('logging')

local httpUtil = require('./utils')

local exports = {}

-- Call a request based on the request path
function getRouter(urls)
  function route(req, res)
    local i, item, handler
    local parsed = url.parse(req.url)
    local method = req.method
    local pathname = parsed.pathname

    for i=1, #urls do
      item = urls[i]
      if item.method == req.method and string.find(pathname, item.path_regex) then
        logging.debug(fmt('Calling handler for path "%s"', pathname))
        handler = item.handler
        handler(req, res)
        return
      end
    end

    logging.debug(fmt('No handler found for path "%s"', pathname))
    httpUtil.returnError(res, 404, fmt('Path "%s" not found', pathname))
  end

  return route
end

exports.getRouter = getRouter
return exports
