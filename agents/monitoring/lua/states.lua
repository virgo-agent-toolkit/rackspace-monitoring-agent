local async = require('async')
local fs = require('fs')
local logging = require('logging')
local path = require('path')
local string = require('string')
local table = require('table')
local utils = require('utils')
local Object = require('object')

local mkdirp = require('./mkdirp').mkdirp

local fmt = string.format

function endswith(s, send)
  return #s >= #send and s:find(send, #s-#send+1, true) and true or false
end

local States = Object:extend()

function States.prototype:initialize(parent_dir)
  self._parent_dir = parent_dir
  self._states = {}
end

function States.prototype:load(callback)
  local ops = {}
  local lself = self

  local function loadIterator(filename, callback)
    local filepath = path.join(self._parent_dir, filename)
    self._states[filename] = {}
    fs.read_file(filepath, function(err, data)
      if err then
        callback(err)
        return
      end

      -- split file into lines
      for w in string.gfind(data, "[^\n]+") do
        -- check for comment
        if not string.find(w, '^#') then
          -- find key/value pairs (delimited by an initial space)
          for key, value in string.gmatch(w, '(%w+) (.*)') do
            self._states[filename][key] = value
          end
        end
      end
      callback()
    end)
  end

  local function checkForStateDirectory(callback)
    fs.exists(self._parent_dir, function(err, exists)
      if err then
        callback(err)
        return
      end
      if exists == false then
        logging.log(logging.INFO, 'Creating state directory ' .. self._parent_dir)
        mkdirp(self._parent_dir, 0600, callback);
      else
        logging.log(logging.INFO, 'Using state directory ' .. self._parent_dir)
        callback()
      end
    end)
  end

  local function readFiles(callback)
    fs.readdir(self._parent_dir, function(err, files)
      local state_files = {}
      for i=1,#files do
        if endswith(files[i], ".state") then
          table.insert(state_files, files[i])
        end
      end
      async.forEach(state_files, iter, callback)
    end)
  end

  table.insert(ops, checkForStateDirectory)
  table.insert(ops, readFiles)

  async.waterfall(ops, callback)
end

function States.prototype:dump(callback)
  callback = callback or function() end
  for filename in pairs(self._states) do
    process.stdout:write(fmt('State: %s\n', filename))
    for k, v in pairs(self._states[filename]) do
      process.stdout:write(fmt('  %s=%s\n', k, v))
    end
  end
  callback()
end

return States
