--[[
--Class CollectorManager
--  - self.metrics = {}
--  -  {
--       collector
--       metrics
--       timestamp
--     }
--  _flush()
--    - emit('metrics', table_o_metrics)
--  _addMetrics(metrics)
--  addCollector(collector)
--  start()
--  stop()
--]]
local Emitter = require('core').Emitter
local Object = require('core').Object
local table = require('table')

-------------------------------------------------------------------------------

local Metrics = Object:extend()
function Metric:initialize(collector, ts, metrics)
  self.collector = collector
  self.timestamp = ts
  self.metrics = metrics
end

-------------------------------------------------------------------------------

local CollectorManager = Emitter:extend()
function CollectorManager:initialize()
  self.collectors = {}
  self.metrics = {}
end

function CollectorManager:addCollector(collector)
end

function CollectorManager:start()
end

function CollectorManager:stop()
end

-------------------------------------------------------------------------------

local exports = {}
exports.CollectorManager = CollectorManager
exports.Metrics = Metrics
return exports
