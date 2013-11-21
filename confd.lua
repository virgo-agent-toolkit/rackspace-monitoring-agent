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

local Confd = Object:extend()


function Confd:initialize()
  self.files = {}
  self.hashes = {}
  self.logger = loggingUtil.makeLogger('Confd')
  async.waterfall(
    {
      function(callback)
        self:_readFiles(callback)
        callback()
      end,
      function(callback)
        self:_writeHashes(callback)
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
        self.logger(err.logtype, err.message)
      end
    end
  )
end


function Confd:getFiles()
  return self.files
end


function Confd:_readFiles(callback)
  local dir = virgo_paths.get(virgo_paths.VIRGO_PATH_CONFD_DIR)
  self.logger(logging.INFO, fmt('reading files in %s', dir))
  fs.readdir(dir, function(err, files)
    local _, fil
    for _, fil in ipairs(files) do
      --only feed .json files to the parser
      if fil:match('.json$') then
	--Read file to the parser
        local fn = path.join(dir,fil)
        fs.readFile(fn, function(err, data) 
          if err then
            --log error
            self.logger(logging.WARNING, fmt('error reading %s, %s', fn, err.message))
            return
          end

          local status, result = pcall(JSON.parse, data)
          if not status or type(result) == 'string' and result:find('parse error: ') then
            -- parse fail
            self.logger(logging.WARNING, fmt('error parsing status:%s, result:%s', status, result))
          else
            self.files[fil] = result
            local d = crypto.digest.new("sha256")
            d:update(data)
            local hash = d:final()
            self.hashes[fil] = hash
            self.logger(logging.INFO, fmt('successfully read: %s, hashed: %s', fn, hash))
          end
        end)
      end
    end
  end)
end

function Confd:_writeHashes(cb)
  local dir = virgo_paths.get(virgo_paths.VIRGO_PATH_PERSISTENT_DIR)
  self.logger(logging.INFO, fmt('writing hashes in %s', dir))
  fs.writeFile(path.join(dir, "confd_hashes.json"), JSON.stringify(self.hashes), function(err)
    cb(err)
  end)
end


return Confd
