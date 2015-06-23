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
timestamp <timestamp>
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
* <timestamp> - By default, all metrics are timestamped with the time when the
  plugin is run, but you can override with a timestamp line. The value is
  milliseconds since Jan. 01 1970 (UTC).
--]]

local table = require('table')
local path = require('path')
local string = require('string')
local fmt = string.format
local readdir = require('fs').readdir
local stat = require('fs').stat
local bit = require('bit')
local los = require('los')

local async = require('async')

local ChildCheck = require('./base').ChildCheck
local constants = require('../constants')
local loggingUtil = require('virgo/util/logging')
local windowsConvertCmd = require('virgo/utils').windowsConvertCmd

local PluginCheck = ChildCheck:extend()

local octal = function(s)
  return tonumber(s, 8)
end

--[[

Constructor.

params.details - Table with the following keys:

- file (string) - Name of the plugin file.
- args (table) - Command-line arguments which get passed to the plugin.
- timeout (number) - Plugin execution timeout in milliseconds.
--]]
function PluginCheck:initialize(params)
  ChildCheck.initialize(self, params)

  if params.details.file == nil then
    params.details.file = ''
  end

  local file = path.basename(params.details.file)
  local args = params.details.args and params.details.args or {}
  local timeout = params.details.timeout and params.details.timeout or constants:get('DEFAULT_PLUGIN_TIMEOUT')

  self._full_path = params.details.file or ''
  self._file = file
  self._pluginPath = path.join(constants:get('DEFAULT_CUSTOM_PLUGINS_PATH'), file)
  self._pluginArgs = args
  self._timeout = timeout
  self._log = loggingUtil.makeLogger(fmt('(plugin=%s, id=%s, iid=%s)', file, self.id, self._iid))
end

function PluginCheck:getType()
  return 'agent.plugin'
end

function PluginCheck:getTargets(callback)
  local targets = {}
  local root = constants:get('DEFAULT_CUSTOM_PLUGINS_PATH')

  local function executeCheck(file, callback)
    stat(path.join(root, file), function(err, s)
      if err then
        return callback()
      end

      if not s.is_file or not s.mode then
        return callback()
      end

      if los.type() == 'win32' then
        table.insert(targets, file)
      else
        local executable = bit.band(s.mode, octal(111))
        if executable ~= 0 then
          table.insert(targets, file)
        end
      end

      callback()
    end)
  end

--  readdir(, function(err, files)
  readdir(root, function(err, files)
    if err then
      local msg

      if err.code == 'ENOENT' then
        msg = fmt('Plugin Directory, %s, does not exist', root)
      else
        msg = fmt('Error Reading Directory, %s', root, err.message)
      end

      return callback(err, { msg })
    end

    async.forEachLimit(files, 5, executeCheck, function(err)
      callback(err, targets)
    end)
  end)
end

function PluginCheck:run(callback)
  local exePath, exeArgs, _ = windowsConvertCmd(self._pluginPath, self._pluginArgs)
  local cenv = self:_childEnv()
  -- Ruby 1.9.1p0 crashes when stdin is closed, so we let luvit take care of
  -- closing the pipe after the process runs.
  self:_runChild(exePath, exeArgs, cenv, callback)
end

exports.PluginCheck = PluginCheck
