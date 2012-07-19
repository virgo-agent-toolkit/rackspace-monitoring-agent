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
/ scripting language. This module is backward compatibile with Cloudkick agent
plugins (https://support.cloudkick.com/Creating_a_plugin).

All the plugins must output information to the standard output in the
format defined bellow:

status <status string>
metric <name 1> <type> <value>
metric <name 2> <type> <value>
metric <name 3> <type> <value>

* <status string> - A status string which includes a summary of the results.
* <name> Name of the metric. No spaces are allowed. If a name contains a dot,
  string before the dot is considered to be a metric dimension.
* <type> - Metric type which can be one of:
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
local loggingUtil = require('../util/logging')

local PluginCheck = BaseCheck:extend()

--[[

Constructor.

params.details - Table with the following keys:

- file (string) - Name of the plugin file.
- args (table) - Command-line arguments which get passed to the plugin.
- timeout (number) - Plugin execution timeout in milliseconds.
--]]
function PluginCheck:initialize(params)
  local file = path.basename(params.details.file)
  local args = params.details.args and params.details.args or {}
  local timeout = params.details.timeout and params.details.timeout or constants.DEFAULT_PLUGIN_TIMEOUT

  BaseCheck.initialize(self, 'agent.plugin', params)

  self._pluginPath = path.join(constants.DEFAULT_CUSTOM_PLUGINS_PATH, file)
  self._pluginArgs = args
  self._timeout = timeout

  self._checkResult = CheckResult:new(self, {})
  self._log = loggingUtil.makeLogger(fmt('(plugin=%s)', file))

  self._gotStatusLine = false
  self._hasError = false
  self._metricCount = 0
end

function PluginCheck:run(callback)
  local stderrBuffer = ''
  local killed = false
  local checkResult = CheckResult:new(self, {})
  local child = nil
  local exePath = self._pluginPath
  local exeArgs = self._pluginArgs
  local lineEmitter = LineEmitter:new()

  if virgo.win32_get_associated_exe ~= nil then
    -- If we are on windows, we want to suport custom plugins like "foo.py",
    -- but this means we need to map the .py file ending to the Python Executable,
    -- and mutate our run path to be like: C:/Python27/python.exe custom_plugins_path/foo.py
    local ext = path.extname(exePath)

    local assocExe, err = virgo.win32_get_associated_exe(ext)
    if ext ~= nil then
        table.insert(exeArgs, 1, self._pluginPath)
        exePath = assocExe
    end
  end

  child = childprocess.spawn(exePath, exeArgs)

  local pluginTimeout = timer.setTimeout(self._timeout, function()
    local timeoutSeconds = (self._timeout / 1000)

    self._log(logging.DEBUG, fmt('Plugin didn\'t finish in %s seconds, killing it...', timeoutSeconds))
    child:kill(9)
    killed = true

    checkResult:setError(fmt('Plugin didn\'t finish in %s seconds', timeoutSeconds))
    self._lastResults = checkResult
    callback(checkResult)
  end)

  lineEmitter:on('data', function(line)
    self:_handleLine(checkResult, line)
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

      self._lastResults = checkResult
      callback(checkResult)
    end)
  end)
end

--[[
Parse a line output by a plugin and mutate CheckResult object (set status
or add a metric).
--]]
function PluginCheck:_handleLine(checkResult, line)
  local statusEndIndex, metricEndIndex, splitString, value, state
  local metricName, metricType, metricValue, dotIndex, internalMetricType, partsCount
  local msg

  if self._hasError then
    -- If a CheckResult already has an error set, all the lines which come after
    -- the error are ignored.
    return
  end

  _, statusEndIndex = line:find('^status')
  _, metricEndIndex = line:find('^metric')

  if statusEndIndex then
    if self._gotStatusLine then
      self._log(logging.WARNING, 'Duplicated status line, ignoring it...')
      return
    end

    value = line:sub(statusEndIndex + 2)
    splitString = split(value, '[^%s]+')
    state = splitString[1]

    if state == 'ok' or state == 'warn' or state == 'err' then
      -- Assume this is an old Cloudkick agent plugin which also outputs plugin
      -- state which is ignored by the new agent. In Cloud monitoring alarm
      -- criteria is used to determine check state.
      table.remove(splitString, 1)
      status = table.concat(splitString, ' ')
    else
      status = value
    end

    self._log(logging.DEBUG, fmt('Setting check status string (status=%s)', status))
    self._gotStatusLine = true
    checkResult:setStatus(status)
  elseif metricEndIndex then
    value = line:sub(metricEndIndex + 2)
    splitString = split(value, '[^%s]+')
    partsCount = #splitString

    if partsCount < 3 then
      msg = 'Metric line not in the following format: metric <name> <type> <value>'
      self._log(logging.WARNING, fmt('Invalid metric line (line=%s) - %s', line, msg))
      self:_setError(checkResult, msg)
      return
    end

    metricName = splitString[1]
    metricType = splitString[2]

    -- Everything after name and type is treated as a metric value
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

    internalMetricType = constants.PLUGIN_TYPE_MAP[metricType]

    if not internalMetricType then
      msg = fmt('Invalid type "%s" for metric "%s"', metricType, metricName)
      self._log(logging.WARNING, fmt('Invalid metric type (type=%s)', metricType))
      self:_setError(checkResult, msg)
      return
    end

    if metricType ~= 'string' and partsCount ~= 3 then
      -- Only values for string metrics can contain spaces
      local msg = fmt('Invalid value "%s" for a non-string metric', metricValue)
      self._log(logging.WARNING, fmt('Invalid metric line (line=%s) - %s', line, msg))
      self:_setError(checkResult, msg)
      return
    end

    local status, err = pcall(function()
      checkResult:addMetric(metricName, metricDimension, internalMetricType,
                            metricValue)
    end)

    if err then
      self._log(logging.WARNING, fmt('Failed to add metric, skipping it... (err=%s)',
                                     tostring(err)))
    else
      self._metricCount = self._metricCount + 1
      self._log(logging.DEBUG, fmt('Metric added (dimension=%s, name=%s, type=%s, value=%s)',
                 tostring(metricDimension), metricName, metricType, metricValue))
    end
  else
    msg = fmt('Unrecognized line "%s"', line)
    self._log(logging.WARNING, msg)
    self:_setError(checkResult, msg)
  end
end

--[[
Set an error on the CheckResult object if and only if the error hasn't been
set yet.
--]]
function PluginCheck:_setError(checkResult, message)
  if self._hasError then
    return
  end

  self._hasError = true
  checkResult:setError(message)
end

local exports = {}
exports.PluginCheck = PluginCheck
return exports
