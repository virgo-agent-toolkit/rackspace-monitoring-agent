local fs = require('fs')
local timer = require('timer')
local table = require('table')
local os = require('os')
local fs = require('fs')
local utils = require('utils')
local Emitter = require('core').Emitter
local Error = require('core').Error
local async = require('async')
local math = require('math')

local JSON = require('json')

local logging = require('logging')
local loggingUtil = require('../util/logging')

local fmt = require('string').format

local Scheduler = Emitter:extend()

-- Scheduler is in charge of determining if a check should be run and then maintaining the state of the checks.
-- checks: a table of BaseCheck
-- callback: function called after the state file is written
function Scheduler:initialize(checks)
  checks = checks or {}
  self._log = loggingUtil.makeLogger('scheduler')
  self._checkMap = {}
  self._checks = checks
  self._runCount = 0
  self:rebuild(checks)
end

function Scheduler:stop()
  if #self._checks == 0 then
    return
  end
  self._log(logging.DEBUG, 'Stopping all active checks')
  for k, v in pairs(self._checks) do
    v:clearSchedule()
  end
end

function Scheduler:start()
  if #self._checks == 0 then
    return
  end
  self._log(logging.DEBUG, 'Starting all active checks')
  for k, v in pairs(self._checks) do
    v:schedule()
  end
end

function Scheduler:numChecks()
  return #self._checks
end

function Scheduler:runCheck()
  self._runCount = self._runCount + 1
end

function Scheduler:completedCheck(check, checkResult)
  self:emit('check.completed', check, checkResult)
end

function Scheduler:_register(check)
  self._log(logging.INFO, fmt('Registering Check %s', check:toString()))
  check:on('run', utils.bind(Scheduler.runCheck, self))
  check:on('completed', utils.bind(Scheduler.completedCheck, self))
  check:schedule()
  table.insert(self._checks, check)
end

function Scheduler:_deregister(check, index)
  self._log(logging.INFO, fmt('Removing Check %s', check:toString()))
  check:removeListener('run')
  check:removeListener('completed')
  check:clearSchedule()
  table.remove(self._checks, index)
end

-- We can rebuid it.  We have the technology.  Better.. faster.. stronger..
-- checks: a table of BaseChecks
-- callback: function called after the state file is written
function Scheduler:rebuild(checks)
  local newCheckMap = {}

  -- todo: the check:run closer captures the checks param. thay may end up being
  -- a memory liability for cases where there are many checks.
  for index, check in ipairs(checks) do
    newCheckMap[check.id] = check
    local vis = self._checkMap[check.id] == nil
    if vis or self._checkMap[check.id]:toString() ~= check:toString() then
      self._checkMap[check.id] = check
      if not vis then
        -- modified check
        self:_deregister(self._checks[index], index)
        self:_register(newCheckMap[check.id])
      else
        -- new check
        self:_register(check)
      end
   end
  end

  -- check all the existing checks for a removal
  for index, check in ipairs(self._checks) do
    if newCheckMap[check.id] == nil then
      self:_deregister(check, index)
    end
  end

  self._checkMap = newCheckMap
end

local exports = {}
exports.Scheduler = Scheduler
return exports
