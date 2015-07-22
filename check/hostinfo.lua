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

local HostInfoCheck = SubProcCheck:extend()
function HostInfoCheck:initialize(params)
  SubProcCheck.initialize(self, params)
  self.details = params.details or {}
  self.type = self.details.type
  self.args = self.details.args
  self.multi_prefix = self.details.multi_prefix or 'multi_'
end

function HostInfoCheck:getType()
  return 'agent.hostinfo'
end

function HostInfoCheck:_runCheckInChild(callback)
  local info = hostinfoCreate(self.type, self.args)
  local function onInfo()
    local cr = CheckResult:new(self, {})
    cr:setAvailable()
    if #info._params == 0 then -- flat
      for k, v in pairs(info._params) do
        cr:addMetric(k, nil, nil, v)
      end
    else -- multiple
      for i, param in ipairs(info._params) do
        for k, v in pairs(param) do
          cr:addMetric(self.multi_prefix .. i .. '_' .. k, nil, nil, v)
        end
      end
    end
    callback(cr)
  end
  info:run(onInfo)
end

exports.HostInfoCheck = HostInfoCheck
