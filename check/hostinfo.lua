--[[
Copyright 2015 Rackspace

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
local SubProcCheck = require('./base').SubProcCheck
local CheckResult = require('./base').CheckResult
local hostinfoCreate = require('../hostinfo').create
local hostinfoGetTypes = require('../hostinfo').getTypes

local HostInfoCheck = SubProcCheck:extend()
function HostInfoCheck:initialize(params)
  SubProcCheck.initialize(self, params)
  self.details = params.details or {}
  self.type = self.details.type
  self.args = self.details.args
  self.multi_prefix = self.details.multi_prefix or self.type:lower() .. '_'
end

function HostInfoCheck:getType()
  return 'agent.hostinfo'
end

function HostInfoCheck:getTargets(callback)
  callback(hostinfoGetTypes())
end

local function recursiveSerializeMetric(t, i, prefix, cr, valuePrefix)
  for k, v in pairs(t) do
    if type(v) == 'table' then
      recursiveSerializeMetric(t, cr, valuePrefix .. '_' .. k)
    else
      if #v > 0 then
        cr:addMetric(prefix .. i .. '_' .. valuePrefix .. '_' .. k, nil, nil, v)
      end
    end
  end
end

function HostInfoCheck:_runCheckInChild(callback)
  local info = hostinfoCreate(self.type, self.args)
  local function onInfo()
    local cr = CheckResult:new(self)
    if info._error then
      cr:setUnavailable()
      cr:setError(info._error)
      return callback(cr)
    end
    cr:setAvailable()
    if #info._params == 0 then -- flat
      for k, v in pairs(info._params) do
        cr:addMetric(k, nil, nil, v)
      end
    else -- multiple
      for i, param in ipairs(info._params) do
        for k, v in pairs(param) do
          if type(v) == 'table' then
            recursiveSerializeMetric(v, i, self.multi_prefix, cr, k or '')
          else
            if (type(v) == 'string' and #v > 0) or type(v) == 'number' then
              cr:addMetric(self.multi_prefix .. i .. '_' .. k, nil, nil, v)
            end
          end
        end
      end
    end
    callback(cr)
  end
  info:run(onInfo)
end

exports.HostInfoCheck = HostInfoCheck
