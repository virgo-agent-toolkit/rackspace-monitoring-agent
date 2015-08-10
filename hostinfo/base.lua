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
local fs = require('fs')
local LineEmitter = require('line-emitter').LineEmitter
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

function HostInfo:getPlatforms()
  return {}
end

function HostInfo:isRegisteredPlatform(callback)
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
end


exports.HostInfo = HostInfo

-------------------------------------------------------------------------------

local HostInfoStdoutSubProc = HostInfo:extend()
function HostInfoStdoutSubProc:initialize(command, args)
  HostInfo.initialize(self)
  self.command = command
  self.args = args or {}
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
  self:isRegisteredPlatform(callback)
  -- assume if command is nil that this vendor is not supported
  if not self.command then
    self._error = string.format('unsupported operating system for %s hostinfo', self:getType())
    return callback()
  end
  self:_execute(callback)
end

exports.HostInfoStdoutSubProc = HostInfoStdoutSubProc

-------------------------------------------------------------------------------

local HostInfoFs = HostInfo:extend()
--local stat = fs.stat
local exists = fs.exists
local createReadStream = fs.createReadStream

function HostInfoFs:initialize(filepath)
  HostInfo.initialize(self)
  self.filepath = filepath
end

function HostInfoFs:exists(cb)
  exists(self.filepath, cb)
end

function HostInfoFs:stat(cb)
  self:exists(self.filepath, function(err, data)
    if err then
      self._error = string.format('File %s doesnt exit: %s', self.filepath, err)
      return cb()
    end
    stat(self.filepath, function(err, fstat)
      if err then
        self._error = string.format('fstat erred out on file %s with err %s', self.filepath, err)
        return cb()
      end
      return cb(fstat)
    end)
  end)
end

function HostInfoFs:readCast(callback)
  self:exists(function(err, data)
    if err or not data then
      self._error = string.format('File %s doesnt exit: %s', self.filepath, err)
      return callback()
    end
    self:_readCast(callback)
  end)
end

function HostInfoFs:_transform()
  assert(false, 'Implement me in the child class')
end

function HostInfoFs:_readCast(callback)
  self.obj = {}
  local stream = createReadStream(self.filepath)
  local le = LineEmitter:new()
  le:on('data', function(line)
    local iscomment = string.match(line, '^#')
    local isblank = string.len(line:gsub("%s+", "")) <= 0
    if not iscomment and not isblank then
      return line
    end
  end)
  stream:pipe(LineEmitter:new()):pipe(self)
    :once('end', function()
    -- Flatten single entry objects
    if #self.obj == 1 then self.obj = self.obj[1] end
    -- Dont insert empty objects into the outTable
    if next(self.obj) then table.insert(self._params, self.obj) end
    return callback()
  end)
end

function HostInfoFs:_execute(callback)
  assert(false, 'Define me in the child class to call one of the hostinfofs funcs')
end

function HostInfoFs:run(callback)
  self:isRegisteredPlatform(callback)
  if not self.filepath then
    self._error = string.format('Filepath not specified. err in hostinfo check: %s', self:getType())
    return callback()
  end
  self:_execute(callback)
end

exports.HostInfoFs = HostInfoFs