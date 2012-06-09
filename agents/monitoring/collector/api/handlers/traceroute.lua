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

local url = require('url')
local table = require('table')
local JSON = require('json')
local setTimeout = require('timer').setTimeout

local Traceroute = require('traceroute').Traceroute

local httpUtil = require('../../http/utils')

local exports = {}

function traceroute(req, res)
  local result = {}
  local parsed = url.parse(req.url, true)
  local qs = parsed.query
  local target = qs['target']
  local streaming = qs['streaming'] == '1'
  local hopCount = 0

  if not target or #target == 0 then
    httpUtil.returnError(res, 400, 'Missing a required "target" argument')
    return
  end

  local tr = Traceroute:new(target)

  tr:traceroute()

  tr:on('error', function(err)
    httpUtil.returnError(res, 500, err.message)
  end)

  tr:on('hop', function(hop)
    local payload

    if streaming then
      if hopCount == 0 then
        res:writeHead(200, {['Content-Type'] = 'application/json'})
      end

      payload = JSON.stringify(hop, {beautify = false, indent_string = '    '})
      res:write(payload .. '\n')
    else
      table.insert(result, hop)
    end

    hopCount = hopCount + 1
  end)

  tr:on('end', function()
    if streaming then
      res:finish('')
    else
      httpUtil.returnJson(res, 200, result)
    end
  end)
end

exports.traceroute = traceroute
return exports
