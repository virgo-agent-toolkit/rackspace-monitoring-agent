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

local async = require('async')
local fs = require('fs')
local path = require('path')
local string = require('string')
local table = require('table')
local utils = require('utils')
local Object = require('core').Object
local logging = require('logging')

local uuid = require('./util/uuid')
local fsUtil = require('./util/fs')

local stateFile = require('./state_file')

local fmt = string.format

local STATE_EXTENSION = '.state'

function endswith(s, send)
  return #s >= #send and s:find(send, #s-#send+1, true) and true or false
end

local States = Object:extend()

function States:initialize(parentDir)
  self._parentDir = parentDir
  self._states = {}
end

function States:load(callback)
  local function iter(filename, callback)
    local filepath = path.join(self._parentDir, filename)
    stateFile.load(filepath, function(err, properties)
      if err then
        callback(err)
        return
      end

      local filenameWithoutExtension = filename:gsub(STATE_EXTENSION, '')
      self._states[filenameWithoutExtension] = properties
      callback()
    end)
  end

  async.waterfall({
    function(callback)
      -- Check if state directory exists and if it doesn't, create it
      fs.exists(self._parentDir, function(err, exists)
        if err then
          callback(err)
          return
        end

        if not exists then
          logging.debug(fmt('State directory (%s) doesn\'t exist, creating it...', self._parentDir))
          fsUtil.mkdirp(self._parentDir, 0600, function(err)
            if err then
              logging.error('Failed to create state directory: ' .. err.message)
            end
            callback(err)
          end)
          return
        end

        callback()
      end)
    end,
    function(callback)
      fs.readdir(self._parentDir, callback)
    end,
    function(files, callback)
      local state_files = {}
      for i=1,#files do
        if endswith(files[i], STATE_EXTENSION) then
          table.insert(state_files, files[i])
        end
      end
      async.forEach(state_files, iter, callback)
    end
  }, callback)
end

function States:dump(callback)
  for filename in pairs(self._states) do
    process.stdout:write(fmt('State: %s\n', filename))
    for k, v in pairs(self._states[filename]) do
      process.stdout:write(fmt('  %s=%s\n', k, v))
    end
  end
  if callback then
    callback()
  end
end

function States:get(stateName)
  return self._states[stateName]
end

return States
