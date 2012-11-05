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
local BaseCheck = require('./base').BaseCheck
local CheckResult = require('./base').CheckResult

local NetworkCheck = BaseCheck:extend()

function NetworkCheck:initialize(params)
  BaseCheck.initialize(self, 'agent.network', params)

  self.interface_name = params.details and params.details.target
end

function NetworkCheck:run(callback)
  -- Perform Check
  local s = sigar:new()
  local netifs = s:netifs()
  local checkResult = CheckResult:new(self, {})
  local usage

  if not self.interface_name then
    checkResult:setError('Missing target parameter; give me an interface.')
    return callback(checkResult)
  end

  local interface = nil
  for i=1, #netifs do
    local name = netifs[i]:info().name
    if name == self.interface_name then
      interface = netifs[i]
      break
    end
  end

  if not interface then
    checkResult:setError('No such interface: ' .. self.interface_name)
  else
    local usage = interface:usage()
    for key, value in pairs(usage) do
      checkResult:addMetric(key, self.interface_name, 'gauge', value)
    end
  end

  -- Return Result
  self._lastResult = checkResult
  callback(checkResult)
end

local exports = {}
exports.NetworkCheck = NetworkCheck
return exports
