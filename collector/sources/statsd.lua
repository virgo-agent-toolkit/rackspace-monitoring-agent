--[[
Copyright 2013 Rackspace

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
local SourceBase = require('../base').SourceBase

local fmt = require('string').format

local logging = require('logging')
local loggingUtil = require('/util/logging')
local statsd = require('/lua_modules/statsd')
local utils = require('utils')

-------------------------------------------------------------------------------

local StatsdSource = SourceBase:extend()
function StatsdSource:initialize(options)
  SourceBase.initialize(self, 'statsd', options)

  self._log(logging.INFO, fmt('StatsD Source'))
  self._log(logging.INFO, fmt('Version: %s', statsd.version()))

  self._statsd = statsd.Statsd:new(options)
	self._statsd:bind()
	self._statsd:on('metrics', function(metrics)
		self:emit('metrics', metrics, self)
	end)

	self._log(logging.INFO, fmt('Port: %s', self._statsd:getOptions().port))
end

-------------------------------------------------------------------------------

local exports = {}
exports.Source = StatsdSource
return exports
