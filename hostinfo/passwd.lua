--[[
Copyright 2015 Rackspace

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
local HostInfo = require('./base').HostInfo
local async = require('async')
local fs = require('fs')
local los = require('los')
local Transform = require('stream').Transform
local execFileToStreams = require('./misc').execFileToStreams

local PASSWD_PATH = '/etc/passwd'
local CONCURRENCY = 5

--[[ Passwordstatus Variables ]]--
local Reader = Transform:extend()
function Reader:initialize()
  Transform.initialize(self, {objectMode = true})
end

function Reader:_transform(data, callback)
  if data and #data > 0 then
    data = data:gsub('[\n|"]','')
    local iter = data:gmatch("%S+")
    self:push({
      name = iter(),
      status = iter(),
      last_changed = iter(),
      minimum_age = iter(),
      warning_period = iter(),
      inactivity_period = iter()
    })
  end
  return callback()
end

local Info = HostInfo:extend()

function Info:run(callback)
  if los.type() ~= 'linux' then
    self._error = 'Unsupported OS for passwdstatus'
    return callback()
  end

  fs.readFile(PASSWD_PATH, function(err, data)
    if err then
      self._error = "Couldn't read /etc/passwd"
      return callback()
    end

    local users = {}

    for line in data:gmatch("[^\r\n]+") do
      local name = line:match("[^:]*")
      table.insert(users, name)
    end

    local function iter(datum, callback)
      local exitCode, command, args
      local called = 2
      command = 'passwd'
      args = {'-S', datum}
      local function done()
        called = called - 1
        if called == 0 then
          if exitCode ~= 0 then
            self._error = 'Process exited with exit code ' .. exitCode
          end
          callback()
        end
      end
      local function onClose(_exitCode)
        exitCode = _exitCode
        done()
      end

      local child, stdout, stderr = execFileToStreams(command,
                                                      args,
                                                      { env = process.env })
      local reader = Reader:new()
      stdout:pipe(reader)
      child:once('close', onClose)
      reader:on('data', function(param)
          table.insert(self._params, param)
        end)
      reader:once('end', done)
    end
    async.forEachLimit(users, CONCURRENCY, iter, callback)
  end)
end

function Info:getType()
  return 'PASSWD'
end

return Info
