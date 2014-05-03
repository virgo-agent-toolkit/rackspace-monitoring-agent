--[[
Copyright 2014 Rackspace

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
local fs = require('fs')
local path = require('path')
local logging = require('logging')
local loggingUtil = require('/base/util/logging')
local fmt = require('string').format
local async = require('async')
local table = require('table')
local JSON = require('json')
local misc = require('/base/util/misc')

local Confd = Object:extend()


-- Confd Object Init
function Confd:initialize(confd_dir, state_dir)
  self.dir = confd_dir or virgo_paths.get(virgo_paths.VIRGO_PATH_CONFD_DIR)
  self.files = {}
  self.logger = loggingUtil.makeLogger('Confd')
end

-- Setup the Confd Object, reading files into list
function Confd:setup(callback)
  async.series(
    {
      function(callback)
        self:_getFileList(callback)
      end,
      function(callback)
        self:_readFiles(callback)
      end,
    },
    function(err)
      if err then
        if err.logtype == nil then
          err.logtype = logging.ERROR
        end
        if err.message == nil or err.message == '' then
          err.message = 'unknown error'
        end
        self.logger(err.logtype, fmt("Setup: %s", err.message))
      end
    end
  )

  callback()
end

-- Get the file list
function Confd:getFiles()
  return self.files
end

-- Build the file list
function Confd:_getFileList(callback)
  self.logger(logging.INFO, fmt('reading files in %s', self.dir))
  fs.readdir(self.dir, function(err, files)
    local _, fil
    local count = 0
    if err then
      if err.code == 'ENOENT' then
        self.logger(logging.ERROR, fmt('Agent-based config dir %s does not exist', self.dir))
      else
        self.logger(logging.ERROR, fmt('error reading dir %s, %s', self.dir, err.message))
      end
    else
      for _, fil in ipairs(files) do
        --only read .yaml files for sending to the AEP
        if fil:match('%.yaml$') then
          self.files[fil] = {}
          count = count + 1
        end
      end
    end
    self.file_count = count
    callback()
  end)
end

-- Read files into the list
function Confd:_readFiles(callback)
  async.forEachTable(self.files, function(fil, _, callback)
    --Read file to the parser
    local fn = path.join(self.dir,fil)
    fs.readFile(fn, function(err, data)
      if err then
        --log error
        self.logger(logging.ERROR, fmt('error reading file %s, %s', fn, err))
      else
        self.files[fil] = data

        self.logger(logging.INFO, fmt('successfully read: %s', fn))
      end
      callback()
    end)
  end, callback)
end

-- Run the Confd Operations, non-blocking
function Confd:run(conn, entity, callback)
  self:_sendFiles(conn, entity, callback)
end

-- Sync all objects of a named type in parallel
function Confd:_sendFiles(conn, entity, callback)
  -- ensure we're bound
  if not entity then
    self.logger(logging.ERROR, "Not sending config files because agent is not bound to an entity")
    callback()
    return
  end

  conn:postConfigFiles(self.files, function(err, response)
    if err then
      callback(err)
      return
    end

    if not response.error then
      self.logger(logging.INFO,
                  fmt('config_file post overall %s',
                      (response.result.success and "success" or "failure")))
      local _, indivres
      for _, indivres in ipairs(response.result.values) do
        if indivres.success then
          self.logger(logging.INFO,
                      fmt('config_file post operation result: %s for %s, handle: %s at %s',
                          (indivres.success and "success" or "failure"),
                          indivres.type,
                          indivres.handle,
                          indivres.location))
        else
          self.logger(logging.ERROR,
                      fmt('config_file post operation result: %s for %s, handle: %s at %s, error %s',
                          (indivres.success and "success" or "failure"),
                          indivres.type,
                          indivres.handle,
                          indivres.location,
                          JSON.stringify(indivres.err)))
        end
      end
    else
      self.logger(logging.ERROR,
                  fmt('config_file post error response, code: %s, msg: %s',
                      response.error.code, response.error.message))
    end
    callback()
  end)
end

function Confd:runOnce(conn, entity, callback)
  if not self.called then
    self.called = true
    self:run(conn, entity, callback)
  else
    callback()
  end
end

return Confd
