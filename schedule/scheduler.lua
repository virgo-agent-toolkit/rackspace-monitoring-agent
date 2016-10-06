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

local table = require('table')
local utils = require('utils')
local Emitter = require('core').Emitter

local logging = require('logging')
local loggingUtil = require('virgo/util/logging')
local math = require('math')
local fmt = require('string').format
local constants = require('../constants')

local Scheduler = Emitter:extend()

-- Scheduler is in charge of determining if a check should be run and then maintaining the state of the checks.
-- checks: a table of BaseCheck
-- callback: function called after the state file is written
function Scheduler:initialize(checks)
  self._log = loggingUtil.makeLogger('scheduler')
  self._checkMap = {}
  self._checks = {}
  self._runCount = 0
  self._minCheckPeriod = constants:get('MAX_CHECK_PERIOD')
  self:rebuild(checks or {})
end

function Scheduler:getCheckMap()
  return self._checkMap
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
  return self._runCount
end

function Scheduler:completedCheck(check, checkResult)
  self:emit('check.completed', check, checkResult)
end

function Scheduler:_register(check)
  check:on('run', utils.bind(Scheduler.runCheck, self))
  check:on('completed', utils.bind(Scheduler.completedCheck, self))
  check:schedule()
  table.insert(self._checks, check)
end

function Scheduler:_deregister(check)
  check:removeListener('run')
  check:removeListener('completed')
  check:clearSchedule()

  for i = #self._checks, 1, -1 do
    if self._checks[i].id == check.id then
      table.remove(self._checks, i)
      return
    end
  end
end

function Scheduler:getCheck(id)
  return self._checkMap[id]
end

function Scheduler:getMinimumCheckPeriod()
  return self._minCheckPeriod
end

-- We can rebuid it.  We have the technology.  Better.. faster.. stronger..
-- checks: a table of BaseChecks
-- callback: function called after the state file is written
function Scheduler:rebuild(checks)
  local newCheckMap = {}

  self._minCheckPeriod = constants:get('MAX_CHECK_PERIOD')

  -- Calculate differences
  for _, check in ipairs(checks) do
    local oldCheck = self:getCheck(check.id)
    local checkScheduleJitter = constants:get('CHECK_SCHEDULE_JITTER')

    newCheckMap[check.id] = check
    self._minCheckPeriod = math.min(check.period * 1000 + checkScheduleJitter, self._minCheckPeriod)

    if oldCheck == nil then
      -- new check
      self._log(logging.DEBUG, fmt('Registering New Check %s', check:toString()))
      self:emit('check.created', check)
    elseif oldCheck:toString() ~= check:toString() then
      -- modified check
      self._log(logging.DEBUG, fmt('Registering Modified Check %s', check:toString()))
      self:emit('check.modified', check)
    end
  end

  -- check all the existing checks for a removal
  for _, check in ipairs(self._checks) do
    if newCheckMap[check.id] == nil then
      self._log(logging.DEBUG, fmt('Removing Check %s', check:toString()))
      self:emit('check.deleted', check)
    end
  end

  -- Remove all checks
  for _, check in ipairs(self._checks) do
    check:clearSchedule()
  end
  self._checks = {}

  -- Register all checks
  for _, check in pairs(newCheckMap) do
    self:_register(check)
  end

  self._checkMap = newCheckMap
end

exports.Scheduler = Scheduler
