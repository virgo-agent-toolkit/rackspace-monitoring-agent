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
local JSON = require('json')
local SinkBase = require('../base').SinkBase
local dgram = require('dgram')
local logging = require('logging')

local fmt = require('string').format

local UDPSink = SinkBase:extend()
function UDPSink:initialize(stream, options)
  SinkBase.initialize(self, 'udp', stream, options)
  self.host = options['monitoring_sinks_udp_host'] or '127.0.0.1'
  self.port = options['monitoring_sinks_udp_port'] or 10087
  self.sock = dgram.createSocket('udp4')
  self._log(logging.INFO, fmt('created (host=%s, port=%s)', self.host, self.port))
end

function UDPSink:push(metrics)
  for i=1, #metrics do
    self.sock:send(JSON.stringify(metrics[i].metrics), self.port, self.host, function()
    end)
  end
end

local exports = {}
exports.Sink = UDPSink
return exports
