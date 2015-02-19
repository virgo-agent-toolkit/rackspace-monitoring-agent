local check = require('../check')
local AgentClient = require('virgo/lib/client/client').AgentClient
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
