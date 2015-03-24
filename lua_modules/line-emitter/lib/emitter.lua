--[[
Copyright 2015 Virgo Agent Toolkit Authors

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

local iStream = require('core').iStream

local function gsplit2(s, sep)
  local lasti, done, g = 1, false, s:gmatch('(.-)'..sep..'()')
  return function()
    if done then return end
    local v,i = g()
    if s == '' or sep == '' then done = true return s end
    if v == nil then done = true return -1, s:sub(lasti) end
    lasti = i
    return v
  end
end

local LineEmitter = iStream:extend()

function LineEmitter:initialize(initialBuffer, options)
  options = options or {}
  self._buffer = initialBuffer or ''
  self._includeNewLine = options.includeNewLine
end

function LineEmitter:write(chunk)
  if self.buffer then 
    chunk = self.buffer .. chunk
  end

  for line, last in gsplit2(chunk, '[\n]') do
    if type(line) == 'number' then
      self.buffer = last
    else
      if self._includeNewLine then
        self:emit('data', line .. '\n')
      else
        self:emit('data', line)
      end
    end
  end
end

local exports = {}
exports.LineEmitter = LineEmitter
return exports
