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

local AgentClient = require('virgo/client').AgentClient

local check = require('../check')
local logging = require('logging')
local table = require('table')

local VirgoAgentClient = AgentClient:extend()
function VirgoAgentClient:initialize(options, connectionStream, types)
  AgentClient.initialize(self, options, connectionStream, types)
end

function VirgoAgentClient:setScheduler(scheduler)
  self._scheduler = scheduler
end

function VirgoAgentClient:scheduleManifest(manifest)
  local checks = self:_createChecks(manifest)
  self._scheduler:rebuild(checks, function()
    self._log(logging.DEBUG, 'Reloaded manifest')
  end)
end

function VirgoAgentClient:_createChecks(manifest)
  local checks = {}

  for i, _ in ipairs(manifest.checks) do
    local check = check.create(manifest.checks[i])
    if check then
      table.insert(checks, check)
    end
  end

  return checks
end

return VirgoAgentClient
