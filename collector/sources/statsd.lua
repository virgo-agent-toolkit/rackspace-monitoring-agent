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
function StatsdSource:initialize(stream, options)
  SourceBase.initialize(self, 'statsd', stream, options)

  self._log(logging.INFO, fmt('StatsD Source'))
  self._log(logging.INFO, fmt('Version: %s', statsd.version()))

  local statsd_options = {
    host = options['monitoring_collectors_statsd_host'],
    port = options['monitoring_collectors_statsd_port']
  }

  local function onMetrics(metrics)
    self:emit('metrics', metrics, self)
  end

  self.statsd = statsd.Statsd:new(statsd_options)
  self.statsd:on('metrics', onMetrics)
  self.statsd:bind()

  self._log(logging.INFO, fmt('Listening on: %s:%s',
            self.statsd:getOptions().host,
            self.statsd:getOptions().port))

end

function StatsdSource:resume()
  self.statsd:run()
end

function StatsdSource:pause()
end

-------------------------------------------------------------------------------

local exports = {}
exports.Source = StatsdSource
return exports
