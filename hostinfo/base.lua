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
local Transform = require('stream').Transform
local env = require('env')
local execFileToStreams = require('./misc').execFileToStreams
local gmtNow = require('virgo/utils').gmtNow
local los = require('los')

-------------------------------------------------------------------------------

local HostInfo = Object:extend()
function HostInfo:initialize()
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
function HostInfoStdoutSubProc:initialize(command, args, metricsHandler)
  HostInfo.initialize(self)
  self.command = command
  self.args = args
  self.metricsHandler = metricsHandler
  assert(self.command)
  assert(self.args)
  assert(self.metricsHandler)
end

function HostInfoStdoutSubProc:getRestrictedPlatforms()
  return {}
end

function HostInfoStdoutSubProc:_execute(callback)
  local exitCode
  local called = 2
  local options = { env = process.env }
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
  self.child, self.stdout, self.stderr = execFileToStreams(self.command, self.args, options)
  self.child:once('close', onClose)
  self.stdout:pipe(self.metricsHandler)
    :on('data', function(obj)
      table.insert(self._params, obj)
    end)
    :once('end', done)
end

function HostInfoStdoutSubProc:run(callback)
  local currentPlatform = los.type()
  for _, platform in pairs(self:getRestrictedPlatforms()) do
    if platform == currentPlatform then
      self._error = 'unsupported operating system for ' .. self:getType()
      return callback()
    end
  end
  self:_execute(callback)
end

exports.HostInfoStdoutSubProc = HostInfoStdoutSubProc

-------------------------------------------------------------------------------

local MetricsHandler = Transform:extend()

function MetricsHandler:initialize()
  Transform.initialize(self, {objectMode = true})
  self._params = {}
end

function MetricsHandler:_transform(line, callback)
  assert(false, '_transform needs to be implemented in child class')
end

function MetricsHandler:setError(err)
  self._params = {}
end

function MetricsHandler:getParams()
  return self._params
end

exports.MetricsHandler = MetricsHandler
