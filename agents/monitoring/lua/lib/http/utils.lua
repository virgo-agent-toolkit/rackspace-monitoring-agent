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
  local code = code or 500
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

exports.returnResponse = returnResponse
exports.returnError = returnError
exports.returnJson = returnJson
return exports
