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

local Transform = require('stream').Transform
local execFileToStreams = require('./misc').execFileToStreams
local gmtNow = require('virgo/utils').gmtNow
local los = require('los')

-------------------------------------------------------------------------------

local HostInfo = Transform:extend()
function HostInfo:initialize()
  Transform.initialize(self, {objectMode = true})
  self._params = {}
  self._error = nil
end

function HostInfo:serialize()
  return {
    error = self._error,
    metrics = self._params,
    timestamp = gmtNow()
  }
end

function HostInfo:run(callback)
  callback()
end

exports.HostInfo = HostInfo

-------------------------------------------------------------------------------

local HostInfoStdoutSubProc = HostInfo:extend()
function HostInfoStdoutSubProc:initialize(command, args)
  HostInfo.initialize(self)
  self.command = command
  self.args = args or {}
end

function HostInfoStdoutSubProc:getPlatforms()
  return {}
end

function HostInfoStdoutSubProc:_execute(callback)
  local exitCode
  local called = 2
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
  self.child, self.stdout, self.stderr = execFileToStreams(self.command,
                                                           self.args,
                                                           { env = process.env })
  self.child:once('close', onClose)
  self.stdout:pipe(self)
    :on('data', function(obj)
      table.insert(self._params, obj)
    end)
    :once('end', done)
end

function HostInfoStdoutSubProc:run(callback)
  local currentPlatform = los.type()
  local found = false
  for _, platform in pairs(self:getPlatforms()) do
    if platform == currentPlatform then
      found = true
      break
    end
  end
  if not found then
    self._error = 'unsupported operating system for ' .. self:getType()
    return callback()
  end
  -- assume if command is nil that this vendor is not supported
  if not self.command then
    self._error = string.format('unsupported operating system for %s hostinfo', self:getType())
    return callback()
  end
  self:_execute(callback)
end

exports.HostInfoStdoutSubProc = HostInfoStdoutSubProc
