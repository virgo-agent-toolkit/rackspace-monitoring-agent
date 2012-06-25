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

--[[

Module for running custom agent plugins written in an arbitrary programing
/ scripting language. This module also contains code for backward compatibility
with Cloudkick agent plugins (https://support.cloudkick.com/Creating_a_plugin).

All the plugins must output information to the standard output in the
format defined bellow.

status <status string>
metric <name 1> <type> <value>
metric <name 2> <type> <value>
metric <name 3> <type> <value>

* <status string> - A status string which includes a summary of the results.
* <name> Name of the metric. No spaces are allowed. If a name contains a dot,
  string before a dot is considered to be a metric dimension.
* type - Metric type which can be one of:
  * string
  * gauge
  * float
  * int
--]]

local table = require('table')
local childprocess = require('childprocess')
local timer = require('timer')
local path = require('path')
local string = require('string')
local fmt = string.format

local logging = require('logging')
local LineEmitter = require('line-emitter').LineEmitter

local BaseCheck = require('./base').BaseCheck
local CheckResult = require('./base').CheckResult
local Metric = require('./base').Metric
local split = require('../util/misc').split
local tableContains = require('../util/misc').tableContains
local lastIndexOf = require('../util/misc').lastIndexOf
local constants = require('../util/constants')

-- Default plugin timeout in seconds
local DEFAULT_PLUGIN_TIMEOUT = 30 * 1000

-- Map external plugin type to internal ones
local PLUGIN_TYPE_MAP = {string = 'string', int = 'int64', float = 'double', gauge = 'gauge'}

local PluginCheck = BaseCheck:extend()

function PluginCheck:initialize(params)
  BaseCheck.initialize(self, params, 'agent.plugin.' .. params.name)

  self._pluginPath = path.join(constants.DEFAULT_CUSTOM_PLUGINS_PATH,
                               params.file)
  self._timeout = params.timeout and params.timeout or DEFAULT_PLUGIN_TIMEOUT
  self._args = params.args and params.args or {}
end

function PluginCheck:run(callback)
  local stderrBuffer = ''
  local callbackCalled = false
  local checkResult = CheckResult:new(self, {})

  local child = childprocess.spawn(self._pluginPath, self._args)
  local lineEmitter = LineEmitter:new()

  local pluginTimeout = timer.setTimeout(self._timeout, function()
    local timeoutSeconds = (self._timeout / 1000)

    logging.debugf('Plugin didn\'t finish in %s seconds, killing it...', timeoutSeconds)
    child:kill(9)

    checkResult:setUnavailable()
    checkResult:setStatus(fmt('Plugin didn\'t finish in %s seconds', timeoutSeconds))
    callbackCalled = true
    callback(checkResult)
  end)

  lineEmitter:on('line', function(line)
    self:_handleLine(checkResult, line)
  end)

  child.stdout:on('data', function(chunk)
    lineEmitter:feed(chunk)
  end)

  child.stderr:on('data', function(chunk)
    stderrBuffer = stderrBuffer .. chunk
  end)

  child:on('exit', function(code)
    timer.clearTimer(pluginTimeout)

    if callbackCalled then
      -- Plugin timed out and callback has already been called
      return
    end

    process.nextTick(function()
      -- Callback is called on the next tick so any pending line processing can
      -- happen before calling a callback.
      if code ~= 0 then
        checkResult:setUnavailable()
        checkResult:setStatus(fmt('Plugin exited with non-zero status code (code=%s)', (code)))
      end

      self._lastResults = checkResult
      callbackCalled = true
      callback(checkResult)
    end)
  end)
end

-- Parse a line output by a plugin and mutate CheckResult object (set status
-- or add a metric).
function PluginCheck:_handleLine(checkResult, line)
  local endIndex, splitString, value, state
  local metricName, metricType, metricValue, dotIndex, internalMetricType, partsCount

  _, endIndex = line:find('^status')

  if endIndex then
    value = line:sub(endIndex + 2)
    splitString = split(value, '[^%s]+')
    state = splitString[1]

    if state == 'ok' or state == 'warn' or state == 'err' then
      -- Assume this is an old Cloudkick agent plugin which also outputs plugin
      -- state which is ignored by the new agent.
      table.remove(splitString, 1)
      status = table.concat(splitString, ' ')
    else
      status = value
    end

    logging.debugf('Setting check status string (status=%s)', status)
    checkResult:setStatus(status)
    return
  end

  _, endIndex = line:find('^metric')

  if endIndex then
    value = line:sub(endIndex + 2)
    splitString = split(value, '[^%s]+')
    partsCount = #splitString

    if partsCount < 3 then
      logging.debugf('Corrupted metric line, skipping it...')
      return
    end

    metricName = splitString[1]
    metricType = splitString[2]

    -- Everything after name and typed is treated as a metric value
    table.remove(splitString, 1)
    table.remove(splitString, 1)

    metricValue = table.concat(splitString, ' ')

    dotIndex = lastIndexOf(metricName, '%.')

    if dotIndex then
      metricDimension = metricName:sub(0, dotIndex - 1)
      metricName = metricName:sub(dotIndex + 1)
    else
      metricDimension = nil
    end

    internalMetricType = PLUGIN_TYPE_MAP[metricType]

    if not internalMetricType then
      logging.debugf('Invalid metric type (%s), skipping metric...', metricType)
      return
    end

    if metricType ~= 'string' and partsCount ~= 3 then
      -- Only values for string metrics can contain spaces
      logging.debugf('Corrupted metric line, skipping it...')
      return
    end

    local status, err = pcall(function()
      checkResult:addMetric(metricName, metricDimension, internalMetricType,
                            metricValue)
    end)

    if err then
      logging.debugf('Failed to add metric, skipping it... (err=%s)',
                     tostring(err))
    else
      logging.debugf('Metric added (dimension=%s, name=%s, type=%s, value=%s)',
                 tostring(metricName), metricName, metricType, metricValue)
    end

    return
  end

  log.debugf('Got unrecognized line (%s), skipping it...', line)
end

local exports = {}
exports.PluginCheck = PluginCheck
return exports
