--[[
Copyright 2012 Rackspace

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

local fs = require('fs')
local string = require('string')
local Object = require('core').Object
local logging = require('logging')

local stateFile = {}

function stateFile._load(data)
  local properties = {}

  -- split file into lines
  for w in string.gfind(data, "[^\n]+") do
    -- check for comment
    if not string.find(w, '^#') then
      -- find key/value pairs (delimited by an initial space)
      for key, value in string.gmatch(w, '(%w+) (.*)') do
        properties[key] = value
      end
    end
  end

  return properties
end

function stateFile.load(path, callback)
  fs.readFile(path, function(err, data)
    if err then
      callback(err)
      return
    end

    callback(nil, stateFile._load(data))
  end)
end

function stateFile.loadSync(path)
  local data = fs.readFileSync(path)
  return stateFile._load(data)
end

return stateFile
