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
local os = require('os')
local table = require('table')
local string = require('string')
local path = require('path')

local Object = require('core').Object
local async = require('async')
local misc = require('./util/misc')

local logging = require('logging')
local request = require('./protocol/request')

local CrashReporter = Object:extend()

function CrashReporter:initialize(binary, bundley, platform, dump_dir, endpoints)
  self.binay = binary
  self.bundle = bundle
  self.platform = platform
  self.dump_dir = dump_dir
  self.endpoints = endpoints
end

function CrashReporter:submit(callback)
  local productName = virgo.default_name:gsub('%-', '%%%-')

  -- TODO: crash report support on !Linux platforms.
  if os.type() ~= 'Linux' then
    callback()
    return
  end

  local function send_and_delete(file, callback)
    local mtime
    local options = {headers={}}

    async.series({
      function(callback)
        fs.stat(file, function(err, stats)
          if err then
            logging.errorf("couldn't stat file: %s  because %s.", self.upload, tostring(err))
            return callback(err)
          end
          mtime = stats.mtime
          options.headers["Content-Type"] = "application/octet-stream"
          options.headers['Content-Length'] = stats.size
          callback()
        end)
      end,
      function(callback)
        local querytable = {
          binary_version = self.binary,
          bundle_version = self.bundle,
          platform = self.platform,
          time = mtime
        }
        --TODO: add to luvit querstring.stringify like nodes
        local querystring = ""
        for key,value in pairs(querytable) do
          querystring = string.format('%s%s=%s&', querystring, key, value)
        end
        options = misc.merge({
          method = "POST",
          path = string.format("/agent-crash-report?%s", querystring),
          endpoints = self.endpoints,
          upload = file
        }, self._options, options)
        request.makeRequest(options, callback)
      end,
      function(callback)
        logging.infof('Upload crash dump, now unlinking: %s', file)
        fs.unlink(file, callback)
      end
      }, function(err, res)
      if err then
        logging.errorf('Error uploading crash report: %s because %s', file, tostring(err))
      end
      callback(err)
    end)
  end

  fs.readdir(self.dump_dir, function (err, files)
    if err then
      return callback(err)
    end

    local reports = {}
    for _, file in ipairs(files) do
      if string.find(file, productName .. "%-crash%-report-.+.dmp") ~= nil then
        logging.infof('Found previous crash report %s/%s', self.dump_dir, file)
        table.insert(reports, path.join(self.dump_dir, file))
      end
    end

    async.forEach(reports, send_and_delete, callback)
  end)
end

local exports = {}
exports.CrashReporter = CrashReporter
return exports

