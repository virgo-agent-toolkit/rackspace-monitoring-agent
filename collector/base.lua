--[[
--Class RackspaceCollector
--  -- Timed
--  --  Throttle
--]]
local Emitter = require('core').Emitter

local CollectorBase = Emitter:extend()
function CollectorBase:initialize(name)
  self.name = name or '<UNDEFINED>'
end

local exports = {}
exports.CollectorBase = CollectorBase
return exports
