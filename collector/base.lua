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

function Base:push(metrics)
  self:emit('metrics', metrics, self)
end

function Base.meta.__tostring(self)
  return self.name
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
exports.Metrics = Metrics
return exports
