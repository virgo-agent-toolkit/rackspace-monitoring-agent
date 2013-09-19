local base = require('./base')
local manager = require('./manager')
local sources = require('./sources')
local sinks = require('./sinks')

local function createSink(stream, name, options)
  local module = sinks[name]
  if not module then
    return nil
  end
  return module.Sink:new(stream, options)
end

local function createSource(stream, name, options)
  local module = sources[name]
  if not module then
    return nil
  end
  return module.Source:new(stream, options)
end

local exports = {}
exports.base = base
exports.manager = manager
exports.sources = sources
exports.sinks = sinks
exports.createSink = createSink
exports.createSource = createSource
return exports
