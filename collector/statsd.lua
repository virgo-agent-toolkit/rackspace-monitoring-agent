local CollectorBase = require('./base').CollectorBase

-------------------------------------------------------------------------------

local StatsdCollector = CollectorBase:extend()
function StatsdCollector:initialize(options)
  CollectorBase.initialize(self, 'statsd')
  self.options = options
end

function StatsdCollector:start()
end

function StatsdCollector:stop()
end

-------------------------------------------------------------------------------

local exports = {}
exports.StatsdCollector = StatsdCollector
return exports
