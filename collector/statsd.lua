local Base = require('./base').Base

-------------------------------------------------------------------------------

local Collector = Base:extend()
function Collector:initialize(options)
  Base.initialize(self, 'statsd', options)
end

-------------------------------------------------------------------------------

local exports = {}
exports.Collector = Collector
return exports
