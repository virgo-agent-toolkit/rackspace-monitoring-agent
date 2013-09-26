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
local SinkBase = require('../base').SinkBase
local logging = require('logging')

local RackspaceMonitoringSink = SinkBase:extend()
function RackspaceMonitoringSink:initialize(stream, options)
  SinkBase.initialize(self, 'rackspace_monitoring', stream, options)
  self._log(logging.INFO, 'created')
end

function RackspaceMonitoringSink:push(metrics)
  self.stream:_sendRawMetrics(metrics)
end

local exports = {}
exports.Sink = RackspaceMonitoringSink
return exports
