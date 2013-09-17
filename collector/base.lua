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
local Emitter = require('core').Emitter
local Object = require('core').Object

local JSON = require('json')

local fmt = require('string').format

-------------------------------------------------------------------------------

local Base = Emitter:extend()
function Base:initialize(name, options)
  self.name = name or '<UNDEFINED>'
  self.options = options or {}
end

function Base:getName()
  return self.name
end

function Base.meta.__tostring(self)
  return self.name
end
-------------------------------------------------------------------------------

local SourceBase = Base:extend()
function SourceBase:initialize(name, options)
  Base.initialize(self, name, options)
end

function SourceBase:push(metrics)
  self:emit('metrics', metrics, self)
end

-------------------------------------------------------------------------------

local SinkBase = Base:extend()
function SinkBase:initialize(name, options)
  Base.initialize(self, name, options)
end

function SinkBase:push(metrics)
end

-------------------------------------------------------------------------------

local Metrics = Object:extend()
function Metrics:initialize(collector, ts, metrics)
  self.collector = collector
  self.timestamp = ts
  self.metrics = metrics
end

function Metrics.meta.__tostring(self)
  local t = {}
  t.collector = self.collector:getName()
  t.timestamp = tostring(self.timestamp)
  t.metrics = JSON.stringify(self.metrics)
  return JSON.stringify(t)
end

-------------------------------------------------------------------------------

local exports = {}
exports.Base = Base
exports.SourceBase = SourceBase
exports.SinkBase = SinkBase
exports.Metrics = Metrics
return exports
