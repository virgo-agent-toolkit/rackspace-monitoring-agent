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
