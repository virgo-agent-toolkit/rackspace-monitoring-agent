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

local Object = require('core').Object
local JSON = require('json')
local fs = require('fs')
local path = require('path')
local logging = require('logging')
local loggingUtil = require('../util/logging')
local fmt = require('string').format
local crypto = require('_crypto')
local async = require('async')
local table = require('table')

local Confd = Object:extend()


function Confd:initialize()
  self.dir = virgo_paths.get(virgo_paths.VIRGO_PATH_CONFD_DIR)
  self.hash_file = path.join(virgo_paths.get(virgo_paths.VIRGO_PATH_PERSISTENT_DIR), "confd_hashes.json")
  self.files = {}
  self.last_hashes = {}
  self.logger = loggingUtil.makeLogger('Confd')
  self.constants = {ERROR='ERROR', UNCHANGED='Unchanged', NEW='New', CHANGED='Changed', DELETED='Deleted'}
end


function Confd:run(callback)
  async.waterfall(
    {
      function(callback)
        self:_getFileList(callback)
      end,
      function(callback)
        self:_readFiles(callback)
      end,
      function(callback)
        self:_readLastFileHashes(callback)
      end,
      function(callback)
        self:_markChangedFiles(callback)
      end,
      function(callback)
        self:writeHashes(callback)
      end
    },
    function(err)
      if err then
        if err.logtype == nil then
          err.logtype = logging.ERROR
        end
        if err.message == nil or err.message == '' then
          err.message = 'unknown error'
        end
        self.logger(err.logtype, fmt("FATAL %s", err.message))
      end
    end
  )
  callback()
end


function Confd:getFiles()
  return self.files
end


function Confd:_getFileList(callback)
  self.logger(logging.INFO, fmt('reading files in %s', self.dir))
  fs.readdir(self.dir, function(err, files)
    local _, fil
    local count = 0
    if err then
      self.logger(logging.WARNING, fmt('error reading %s, %s', self.dir, err.message))
    else
      for _, fil in ipairs(files) do
        --only feed .json files to the parser
        if fil:match('.json$') then
          self.files[fil] = {}
          count = count + 1
        end
      end
    end
    self.file_count = count
    callback()
  end)
end


function Confd:_readFiles(callback)
  local _, fil
  local count = 0
  for fil, _ in pairs(self.files) do
    --Read file to the parser
    local fn = path.join(self.dir,fil)
    fs.readFile(fn, function(err, data) 
      if err then
        --log error
        self.files[fil].status = self.constants.ERROR
        self.logger(logging.WARNING, fmt('error reading %s, %s', fn, err.message))
      else
        local status, result = pcall(JSON.parse, data)
        if not status or type(result) == 'string' and result:find('parse error: ') then
          -- parse fail
          self.files[fil].status = self.constants.ERROR
          self.logger(logging.WARNING, fmt('error parsing status:%s, result:%s', status, result))
        else
          self.files[fil].data = result
          local d = crypto.digest.new("sha256")
          d:update(data)
          local hash = d:final()
          self.files[fil].hash = hash
          self.files[fil].status = self.constants.NEW
        self.logger(logging.INFO, fmt('successfully read: %s, hashed: %s', fn, hash))
        end
      end
      count = count + 1
      if count == self.file_count then
        callback()
      end
    end)
  end
end


function Confd:_readLastFileHashes(callback)
  self.logger(logging.INFO, fmt('reading hashes from %s', self.hash_file))
  fs.readFile(self.hash_file, function(err, data)
    if err then
      self.logger(logging.WARNING, fmt('error reading %s, %s', self.hash_file, err.message))
    else
      local status, result = pcall(JSON.parse, data)
      if not status or type(result) == 'string' and result:find('parse error: ') then
        self.logger(logging.WARNING, fmt('error parsing hashes:%s, result:%s', status, result))
      else
        self.last_hashes = result
      end
    end
    callback()
  end)
end


function Confd:_markChangedFiles(callback)
  local fil, _
  for fil, _ in pairs(self.last_hashes) do
    if not self.files[fil] then
      self.files[fil].status = self.constants.DELETED
    end
    if self.last_hashes[fil] ~= self.files[fil].hash then
      if self.files[fil].status ~= self.constants.ERROR then
        self.files[fil].status = self.constants.CHANGED
      end
    else
      self.files[fil].status = self.constants.UNCHANGED
    end
    self.logger(logging.INFO, fmt('%s is marked as %s', fil, self.files[fil].status))
  end
  callback()
end

function Confd:writeHashes(callback)
  self.logger(logging.INFO, fmt('writing hashes into %s', self.hash_file))
  local hashes = {}
  local _, fil
  for fil, _ in pairs(self.files) do
    hashes[fil] = self.files[fil].hash
  end
  fs.writeFile(self.hash_file, JSON.stringify(hashes), function(err)
    if err then
      self.logger(logging.WARNING, fmt('error writing hashes: %s', err.message))
    end
    callback()
  end)
end


return Confd
