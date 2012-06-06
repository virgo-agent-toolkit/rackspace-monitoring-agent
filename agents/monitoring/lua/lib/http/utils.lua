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

local http = require('http')
local parse = require('url').parse
local JSON = require('json')

local exports = {}

function returnResponse(res, code, headers, data)
  data = data or ''
  headers = headers or {}

  if data then
    headers['Content-Length'] = #data
  end

  res:writeHead(code, headers)
  res:finish(data)
end

function returnError(res, code, msg)
  local code = code and code or 500
  local data = {}

  data['error'] = msg

  returnJson(res, code, data)
end

function returnJson(res, code, data)
  local headers = {}
  headers['Content-Type'] = 'application/json'
  data = JSON.stringify(data, {beautify = true, indent_string = '    '})
  returnResponse(res, code, headers, data)
end

function request(url, method, headers, payload, options, callback)
  method = method and method or 'GET'
  headers = headers and headers or {}
  payload = payload and payload or ''
  options = options and options or {}

  local parsed = parse(url)
  local buffer = ''

  headers['Content-Length'] = #payload

  local client = http.request({
    host = parsed.hostname,
    port = parsed.port,
    path = parsed.pathname .. parsed.search,
    headers = headers
  },

  function (res)
    res:on('error', callback)

    res:on('data', function (chunk)
      buffer = buffer .. chunk
    end)

    res:on('end', function()
      if options.parseResponse then
        buffer = JSON.parse(buffer)
      end

      res.body = buffer
      callback(nil, res)
    end)
  end)

  client:on('error', callback)
end

exports.returnResponse = returnResponse
exports.returnError = returnError
exports.returnJson = returnJson
exports.request = request
return exports
