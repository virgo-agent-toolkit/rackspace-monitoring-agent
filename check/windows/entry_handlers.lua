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

local string = require('string')

local exports = {}

-- Example Entry Handler for converting an entry to a metric
exports.prototype = function(self, entry)
  local metric = nil
  if entry.Name ~= nil then
    metric = {
      Name = entry.Name,
      Dimension = nil,
      Type = 'string',
      Value = entry.Value,
      unit = ''
    }
  end
  return metric
end

-- Simple Entry Handler to support integers
exports.simple = function(self, entry)
  local metric = nil
  if entry.Name then
    local type_map = {
      int='int64'
    }

    local type = 'string'
    if type_map[string.lower(entry.Type)] then
      type = type_map[string.lower(entry.Type)]
    end

    metric = {
      Name = entry.Name,
      Dimension = nil,
      Type = type,
      Value = entry.Value,
      unit = ''
    }
  end
  return metric
end

return exports
