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
local Base = require('../base').Base
local statsd = require('/lua_modules/statsd')
local logging = require('logging')
local loggingUtil = require('/util/logging')
local fmt = require('string').format

-------------------------------------------------------------------------------

local Collector = Base:extend()
function Collector:initialize(options)
  Base.initialize(self, 'statsd', options)
  self._log = loggingUtil.makeLogger('collector.statsd')
  self._log(logging.INFO, fmt('StatsD Collector'))
  self._log(logging.INFO, fmt('Version: %s', statsd.version()))
  self._statsd = statsd.Statsd:new()
end

-------------------------------------------------------------------------------

local exports = {}
exports.Collector = Collector
return exports
