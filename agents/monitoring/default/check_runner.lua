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


local async = require('async')
local Emitter = require('core').Emitter
local JSON = require('json')
local checks = require('monitoring/default/check')

local exports = {}

local CheckRunner = Emitter:extend()

function CheckRunner:initialize(checkType)
  self._checkType = checkType
  self._cr = nil
  self._details = nil
end

function CheckRunner:getDetails(callback)
  local ENV_PREFIX = 'RAX_'
  local details = {}

  self._id = process.env[ENV_PREFIX .. 'CHECK_ID']
  self._period = process.env[ENV_PREFIX .. 'CHECK_PERIOD']
  if self._period == nil then
    self._period = 30
  else
    self._period = tonumber(self._period)
  end

  for k,v in pairs(process.env) do
    local found, offset = k:find('^' .. ENV_PREFIX ..'DETAILS_')
    if found then
      local nk = k:sub(offset + 1)
      details[nk:lower()] = v
    end
  end
  self._details = details
  callback(nil)
end

function CheckRunner:run(callback)
  local checkParams = {
    period = self._period,
    id = self._id,
    type = self._checkType,
    details = self._details,
  }

  local check = checks.create(checkParams)
  check:_runCheckInChild(function(cr)
    self._cr = cr
    callback(nil)
  end)
end

function CheckRunner:reportError(callback)
  p('SUCCESS', self._cr)
  callback()
end

function CheckRunner:report(callback)
  p('ERROR', self._cr)
  callback()
end


exports.run = function(argv)
  local checkType = argv.x
  local cr = CheckRunner:new(checkType)

  async.series({
    function(callback)
      cr:getDetails(callback)
    end,
    function(callback)
      cr:run(callback)
    end,
  },
  function (err)
    if err then
      cr:reportError(err, function ()
        process.exit(1)
      end)
    else
      cr:report(function ()
        process.exit(0)
      end)
    end
  end)
end

return exports
