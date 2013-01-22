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

local Emitter = require('core').Emitter
local JSON = require('json')
local LineEmitter = require('line-emitter').LineEmitter
local Object = require('core').Object
local childprocess = require('childprocess')
local env = require('env')
local fmt = require('string').format
local logging = require('logging')
local os = require('os')
local table = require('table')
local timer = require('timer')
local vtime = require('virgo-time')
local utils = require('utils')

local constants = require('../util/constants')
local loggingUtil = require('../util/logging')
local tableContains = require('../util/misc').tableContains
local toString = require('../util/misc').toString
local lastIndexOf = require('../util/misc').lastIndexOf
local split = require('../util/misc').split

local BaseCheck = Emitter:extend()
local CheckResult = Object:extend()
local Metric = Object:extend()

local VALID_METRIC_TYPES = {'string', 'gauge', 'int32', 'uint32', 'int64', 'uint64', 'double'}
local VALID_STATES = {'available', 'unavailable'}


function BaseCheck:initialize(checkType, params)
  self.id = tostring(params.id)
  self.period = tonumber(params.period)
  self._firstRun = true
  self._timer = nil
  self._type = checkType
  self._log = loggingUtil.makeLogger(fmt('Check (%s)', checkType))

  self._lastResult = nil
end

function BaseCheck:run(callback)
  -- do something, produce a CheckResult
  local checkResult = CheckResult:new(self, {})
  self._lastResult = checkResult
  callback(checkResult)
end

function BaseCheck:getType()
  return self._type
end

--[[
  Get targets for a specific check.

  callback(err, targets)
    If targets is nil then there are no targets available for the check.
    If targets is an empty array, then we could not find any targets.
]]--
function BaseCheck:getTargets(callback)
  if callback then
    callback()
  end
end

--[[
Retreieve the summary information of the check.

obj - optional - optional parameters for the resulting string.
]]--
function BaseCheck:getSummary(obj)
  local str = ''
  obj = obj or {}
  if self._lastResult and not obj['status'] then
    obj['state'] = self._lastResult:getState()
  end
  if obj then
    for k, v in pairs(obj) do
      str = str .. fmt(', %s=%s', k, v)
    end
  end
  return fmt('(id=%s, type=%s%s)', self.id, self._type, str)
end

function BaseCheck:toString()
  return fmt('%s (id=%s, period=%ss)', self._type, self.id, self.period)
end

function BaseCheck:_runCheck()
  local fired = false
  local timeoutTimer

  self._timer = nil
  self:emit('run', self)

  local function emitCompleted(checkResult)
    if fired then
      return
    end

    self._log(logging.DEBUG, fmt('re-schedueling check %s', self:getSummary()))

    fired = true
    timer.clearTimer(timeoutTimer)
    self:schedule()
    process.nextTick(function()
      self:emit('completed', self, checkResult)
    end)
  end

  timeoutTimer = timer.setTimeout((self.period * 1000), function()
    local cr = CheckResult:new(self)
    self._log(logging.INFO, fmt('check timed out %s', self:getSummary()))

    self:emit('timeout', self)
    cr:setStatus('Timeout in Run Check')
    emitCompleted(cr)
  end)

  local status, err = pcall(function()
    self:run(function(checkResult)
      self._log(logging.INFO, fmt('check completed %s', self:getSummary()))
      emitCompleted(checkResult)
    end)
  end)

  if not status then
    local msg
    local cr = CheckResult:new(self)
    if type(err) == 'string' then
      msg = err
    else
      msg = tostring(err)
    end
    cr:setStatus(msg)
    emitCompleted(cr)
  end
end

function BaseCheck:schedule()
  if self._timer then
    return
  end
  if self._firstRun then
    self._firstRun = false
    process.nextTick(function()
      self:_runCheck()
    end)
    return
  end
  self._log(logging.INFO, fmt('%s scheduled for %ss', self:toString(), self.period))
  self._timer = timer.setTimeout(self.period * 1000, utils.bind(BaseCheck._runCheck, self))
end

function BaseCheck:clearSchedule()
  if not self._timer then
    return
  end
  timer.clearTimer(self._timer)
  self._timer = nil
end

function BaseCheck:serialize()
  return {
    id = self.id,
    period = self.period
  }
end

local ChildCheck = BaseCheck:extend()

function ChildCheck:initialize(checkType, params)
  BaseCheck.initialize(self, checkType, params)
  self._log = nil
  if params.details == nil then
    params.details = {}
  end
  self._params = params
end

--[[
Add a metric to CheckResult object with proper logging and error handling
--]]
function ChildCheck:_addMetric(runCtx, checkResult, metricName, metricDimension, metricType, metricValue, metricUnit)
  local internalMetricType, msg

  local function matcher(v)
    return v == metricType
  end

  if tableContains(matcher, VALID_METRIC_TYPES) then
    internalMetricType = metricType
  else
    internalMetricType = constants.PLUGIN_TYPE_MAP[metricType]
  end

  if not internalMetricType then
    msg = fmt('Invalid type "%s" for metric "%s"', metricType, metricName)
    self._log(logging.WARNING, fmt('Invalid metric type (type=%s)', metricType))
    self:_setError(runCtx, checkResult, msg)
    return
  end

  local status, err = pcall(function()
    checkResult:addMetric(metricName, metricDimension, internalMetricType,
                          metricValue, metricUnit)
  end)

  if err then
    self._log(logging.WARNING, fmt('Failed to add metric, skipping it... (err=%s)',
                                   tostring(err)))
  else
    self._log(logging.DEBUG, fmt('Metric added (dimension=%s, name=%s, type=%s, value=%s, unit=%s)',
               tostring(metricDimension), metricName, metricType, metricValue, tostring(metricUnit)))
  end
end

--[[
Parse a line output by a plugin and mutate CheckResult object (set status
or add a metric).
--]]
function ChildCheck:_handleLine(runCtx, checkResult, line)
  local stateEndIndex, statusEndIndex, metricEndIndex, splitString, value, state
  local metricName, metricType, metricValue, metricUnit, dotIndex, internalMetricType
  local msg, partsCount

  if runCtx.hasError then
    -- If a CheckResult already has an error set, all the lines which come after
    -- the error are ignored.
    return
  end

  _, statusEndIndex = line:find('^status')
  _, stateEndIndex = line:find('^state')
  _, metricEndIndex = line:find('^metric')

  if statusEndIndex then
    if runCtx.gotStatusLine then
      self._log(logging.WARNING, 'Duplicated status line, ignoring it...')
      return
    end

    value = line:sub(statusEndIndex + 2)
    splitString = split(value, '[^%s]+')
    state = splitString[1]

    if state == 'ok' or state == 'warn' or state == 'err' then
      -- Assume this is an old Cloudkick agent plugin which also outputs plugin state,
      -- formatted like so: "status ok Everything is normal"
      -- We parse and set the status message here, and additionally inclue state as a 
      -- string metric. This is purely a compatability convenience.
      self:_addMetric(runCtx, checkResult, 'legacy_state', nil, 'string', state, nil)
      table.remove(splitString, 1)
      status = table.concat(splitString, ' ')
    else
      status = value
    end

    self._log(logging.DEBUG, fmt('Setting check status string (status=%s)', status))
    runCtx.gotStatusLine = true
    checkResult:setStatus(status)
  elseif stateEndIndex then
    if runCtx.gotStateLine then
      self._log(logging.WARNING, 'Duplicated state line, ignoring it...')
      return
    end

    value = line:sub(stateEndIndex + 2)

    if value ~= 'available' and value ~= 'unavailable' then
      msg = 'State line not in the following format: <available|unavailable>'
      self._log(logging.WARNING, fmt('Invalid state line (line=%s) - %s', line, msg))
      self:_setError(runCtx, checkResult, msg)
      return
    end

    runCtx.gotStateLine = true
    if value == 'available' then
      checkResult:setAvailable()
    else
      checkResult:setUnavailable()
    end
  elseif metricEndIndex then
    value = line:sub(metricEndIndex + 2)
    splitString = split(value, '[^%s]+')
    partsCount = #splitString

    if partsCount < 3 then
      msg = 'Metric line not in the following format: metric <name> <type> <value> [<unit>]'
      self._log(logging.WARNING, fmt('Invalid metric line (line=%s) - %s', line, msg))
      self:_setError(runCtx, checkResult, msg)
      return
    end

    metricName = splitString[1]
    metricType = splitString[2]

    -- Everything after name and type and unit are removed is treated as metric value
    if metricType ~= 'string' and partsCount == 4 then
      metricUnit = splitString[4]
      table.remove(splitString, 4)
    end
    table.remove(splitString, 1)
    table.remove(splitString, 1)

    metricValue = table.concat(splitString, ' ')

    dotIndex = lastIndexOf(metricName, '%.')
    if dotIndex then
      -- Metric name contains a dimension key
      metricDimension = metricName:sub(0, dotIndex - 1)
      metricName = metricName:sub(dotIndex + 1)
    else
      metricDimension = nil
    end

    if metricType ~= 'string' and partsCount > 4 then
      -- Only values for string metrics can contain spaces
      local msg = fmt('Invalid "<value> [<unit>]" combination "%s" for a non-string metric', metricValue)
      self._log(logging.WARNING, fmt('Invalid metric line (line=%s) - %s', line, msg))
      self:_setError(runCtx, checkResult, msg)
      return
    end

    self:_addMetric(runCtx, checkResult, metricName, metricDimension, metricType, metricValue, metricUnit)

  else
    msg = fmt('Unrecognized line "%s"', line)
    self._log(logging.WARNING, msg)
    self:_setError(runCtx, checkResult, msg)
  end
end

function ChildCheck:_runChild(exePath, exeArgs, environ, callback)
  local checkResult = CheckResult:new(self, {})
  local stderrBuffer = ''
  local killed = false
  local lineEmitter = LineEmitter:new()
  -- Context for _handleLine to store stuff between output lines
  local runCtx = {}

  local child = childprocess.spawn(exePath,
                                   exeArgs,
                                   { env = environ })

  local pluginTimeout = timer.setTimeout(self._timeout, function()
    local timeoutSeconds = (self._timeout / 1000)

    self._log(logging.DEBUG, fmt("Plugin didn't finish in %s seconds, killing it...", timeoutSeconds))
    child:kill(9)
    killed = true

    checkResult:setError(fmt("Plugin didn't finish in %s seconds", timeoutSeconds))
    self._lastResult = checkResult
    callback(checkResult)
  end)

  lineEmitter:on('data', function(line)
    self:_handleLine(runCtx, checkResult, line)
  end)

  child.stdout:on('data', function(chunk)
    lineEmitter:write(chunk)
  end)

  child.stderr:on('data', function(chunk)
    stderrBuffer = stderrBuffer .. chunk
  end)

  child:on('exit', function(code)
    timer.clearTimer(pluginTimeout)

    if killed then
      -- Plugin timed out and callback has already been called.
      return
    end

    process.nextTick(function()
      -- Callback is called on the next tick so any pending line processing can
      -- happen before calling a callback.
      if code ~= 0 then
        checkResult:setError(fmt('Plugin exited with non-zero status code (code=%s)', (code)))
      end
      self._lastResult = checkResult
      callback(checkResult)
    end)
  end)

  return child
end

--[[
Set an error on the CheckResult object if and only if the error hasn't been
set yet.
--]]
function ChildCheck:_setError(runCtx, checkResult, message)
  if runCtx.hasError then
    return
  end

  runCtx.hasError = true
  checkResult:setError(message)
end

function ChildCheck:_childEnv()
  local ENV_PREFIX = 'RAX_'
  local k,v
  local cenv = {}

  -- process.env isn't a real table, but this works, so iterate rather than using a merge() function.
  for k,v in pairs(process.env) do
    cenv[k] = v
  end

  cenv[ENV_PREFIX .. 'CHECK_ID'] = self.id
  cenv[ENV_PREFIX .. 'CHECK_PERIOD'] = tostring(self.period)
  cenv[ENV_PREFIX .. 'CHECK_TYPE'] = self._type

  for k,v in pairs(self._params.details) do
    cenv[ENV_PREFIX .. 'DETAILS_' .. k:upper()] = tostring(v)
  end

  return cenv
end


local SubProcCheck = ChildCheck:extend()

function SubProcCheck:initialize(checkType, params)
  ChildCheck.initialize(self, checkType, params)
  self._timeout = params.details.timeout and params.details.timeout or constants.DEFAULT_PLUGIN_TIMEOUT
  self._log = loggingUtil.makeLogger(fmt('(plugin=%s)', checkType))
end

function SubProcCheck:run(callback)
  local args = {
    '-n',
    '-e',
    'default/check_runner',
    '--zip',
    virgo.loaded_zip_path,
    '-x',
    self:getType()
  }

  local cenv = self:_childEnv()
  local child = self:_runChild(process.execPath, args, cenv, callback)

  if child.stdin._closed ~= true then
    child.stdin:close()
  end
end


function SubProcCheck:_findLibrary(mysqlexact, patterns, paths)
  local ffi = require('ffi')
  local clib = nil
  local i,exact

  local function loadsharedobj(name)
    local err, lib = pcall(ffi.load, name, true)
    if err == true then
      clib = lib
    end
  end

  for i,exact in ipairs(mysqlexact) do
    loadsharedobj(exact)
    if clib ~= nil then
      break
    end
  end

  -- TODO: path grepping with patterns and paths

  local mocker = env.get('VIRGO_SUBPROC_MOCK')
  if mocker ~= nil then
    local mock = require(mocker)
    clib = mock.mock(clib)
  end

  return clib
end



function CheckResult:initialize(check, options)
  self._options = options or {}
  self._metrics = {}
  self._state = 'available'
  self._status = 'success'
  self._check = check
  self:setTimestamp(self._options.timestamp)
  self._timestamp = vtime.now()
end

function CheckResult:getTimestamp()
  return self._timestamp
end

function CheckResult:setTimestamp(timestamp)
  self._timestamp = timestamp or vtime.now()
  return self._timestamp
end

function CheckResult:setAvailable()
  self._state = 'available'
end

function CheckResult:setUnavailable()
  self._state = 'unavailable'
end

function CheckResult:getState()
  return self._state
end

function CheckResult:getStatus()
  local status = self._status and self._status or ''
  return status
end

function CheckResult:setStatus(status)
  self._status = status
end

function CheckResult:setError(message)
  self:setUnavailable()
  self:setStatus(message)
end

function CheckResult:addMetric(name, dimension, type, value, unit)
  local metric = Metric:new(name, dimension, type, value, unit)

  if not self._metrics[metric.dimension] then
    self._metrics[metric.dimension] = {}
  end

  self._metrics[metric.dimension][metric.name] = {t = metric.type, v = metric.value, u = metric.unit}
end

function CheckResult:getMetrics()
  return self._metrics
end

function CheckResult:toString()
  return toString(self)
end


-- Serialize a result to the format which is understood by the endpoint.
function CheckResult:serialize()
  local dimension, metric
  local result = {}

  for dimension, metrics in pairs(self._metrics) do
    if dimension == 'none' then
      dimension = JSON.null
    end

    table.insert(result, {dimension, metrics})
  end

  return result
end

function CheckResult:serializeAsPluginOutput()
  local result = {}
  local k,v,j,metric
  local line

  table.insert(result, 'state '.. self:getState())
  table.insert(result, 'status '.. self:getStatus())

  local m = self:getMetrics()

  for k,v in pairs(m) do
    for j,metric in pairs(v) do
      local mname
      if (k ~= 'none') then
        mname = k .. '.' .. j
      else
        mname = j
      end

      line = 'metric ' .. mname .. ' ' .. metric.t .. ' ' .. metric.v
      if metric.u then
        line = line .. ' ' .. metric.u
      end
      table.insert(result, line)
    end
  end

  return table.concat(result, '\n') .. '\n'
end

function Metric:initialize(name, dimension, type, value, unit)
  self.name = name
  self.dimension = dimension or 'none'
  self.value = tostring(value)
  self.unit = unit

  if type then
    if not tableContains(function(v) return type == v end, VALID_METRIC_TYPES) then
      error('Invalid metric type: ' .. type)
    end
    self.type = type
  else
    self.type = getMetricType(value)
  end
end


-- Determinate the metric type based on the value type.
function getMetricType(value)
  local valueType = type(value)

  if valueType == 'string' then
    -- TODO gauge
    return 'string'
  elseif valueType == 'boolean' then
    return 'bool'
  elseif valueType == 'number' then
    if not tostring(value):find('%.') then
      -- TODO int32, uint32, uint64
      return 'int64'
    else
      return 'double'
    end
  end
end

local exports = {}
exports.VALID_METRIC_TYPES = VALID_METRIC_TYPES
exports.BaseCheck = BaseCheck
exports.ChildCheck = ChildCheck
exports.SubProcCheck = SubProcCheck
exports.CheckResult = CheckResult
exports.Metric = Metric
return exports
