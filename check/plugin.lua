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
metric <name 1> <type> <value> [<unit>]
metric <name 2> <type> <value> [<unit>]
metric <name 3> <type> <value> [<unit>]

* <status string> - A status string which includes a summary of the results.
* <name> Name of the metric. No spaces are allowed. If a name contains a dot,
  string before the dot is considered to be a metric dimension.
* <type> - Metric type which can be one of:
  * string
  * gauge
  * float
  * int
* [<unit>] - Metric unit, optional. A string representing the units of the metric
  measurement. Units may only be provided on non-string metrics, and may not
  contain any spaces. Examples: 'bytes', 'milliseconds', 'percent'.
--]]

local table = require('table')
local childprocess = require('childprocess')
local timer = require('timer')
local path = require('path')
local string = require('string')
local fmt = string.format

local logging = require('logging')
local LineEmitter = require('line-emitter').LineEmitter

local ChildCheck = require('./base').ChildCheck
local CheckResult = require('./base').CheckResult
local Metric = require('./base').Metric
local split = require('/base/util/misc').split
local tableContains = require('/base/util/misc').tableContains
local lastIndexOf = require('/base/util/misc').lastIndexOf
local constants = require('/base/util/constants')
local loggingUtil = require('/base/util/logging')

local toString = require('/base/util/misc').toString

local PluginCheck = ChildCheck:extend()

--[[

Constructor.

params.details - Table with the following keys:

- file (string) - Name of the plugin file.
- args (table) - Command-line arguments which get passed to the plugin.
- timeout (number) - Plugin execution timeout in milliseconds.
--]]
function PluginCheck:initialize(params)
  ChildCheck.initialize(self, params)

  local file = path.basename(params.details.file)
  local args = params.details.args and params.details.args or {}
  local timeout = params.details.timeout and params.details.timeout or constants.DEFAULT_PLUGIN_TIMEOUT

  self._pluginPath = path.join(constants.DEFAULT_CUSTOM_PLUGINS_PATH, file)
  self._pluginArgs = args
  self._timeout = timeout
  self._log = loggingUtil.makeLogger(fmt('(plugin=%s)', file))
end

function ChildCheck:toString()
  local argString = table.concat(self._pluginArgs, ',')
  if argString == '' then
    argString = '(none)'
  end
  return fmt('%s (id=%s, iid=%s, period=%ss, args=%s)', self.getType(), self.id, self._iid, self.period, argString)
end

function PluginCheck:getType()
  return 'agent.plugin'
end

function PluginCheck:run(callback)
  local exePath = self._pluginPath
  local exeArgs = self._pluginArgs
  local ext = path.extname(exePath)

  if virgo.win32_get_associated_exe ~= nil and ext ~= "" then
    -- If we are on windows, we want to suport custom plugins like "foo.py",
    -- but this means we need to map the .py file ending to the Python Executable,
    -- and mutate our run path to be like: C:/Python27/python.exe custom_plugins_path/foo.py
    local assocExe, err = virgo.win32_get_associated_exe(ext)
    if assocExe ~= nil then
        table.insert(exeArgs, 1, self._pluginPath)
        exePath = assocExe
    else
        self._log(logging.WARNING, fmt('error getting associated executable for "%s": %s', ext, err))
    end
  end

  local cenv = self:_childEnv()
  local child = self:_runChild(exePath, exeArgs, cenv, callback)
  if child.stdin._closed ~= true then
    child.stdin:close()
  end
end


local exports = {}
exports.PluginCheck = PluginCheck
return exports
