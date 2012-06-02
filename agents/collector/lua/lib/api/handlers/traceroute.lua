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

local Traceroute = require('traceroute').Traceroute

local httpUtil = require('../../http/utils')

local exports = {}

function traceroute(req, res)
  local result = {}
  local tr = Traceroute:new(target)

  tr:traceroute()

  tr:on('error', function(err)
    httpUtil.returnError(500, err.message)
  end)

  tr:on('hop', function(hop)
    table.insert(result, hop)
  end)

  tr:on('end', function()
    httpUtil.returnJson(res, 200, result)
  end)
end

exports.traceroute = traceroute
return exports
