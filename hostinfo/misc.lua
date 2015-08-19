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

local LineEmitter = require('line-emitter').LineEmitter
local childProcess = require('childprocess')
local fs = require('fs')
local sigar = require('sigar')
local Stream = require('stream').Duplex
local Transform = require('stream').Transform

local function read(filePath)
  local Stream = Transform:extend()
  function Stream:initialize()
    Transform.initialize(self, {objectMode = true})
  end
  function Stream:_transform(line, cb)
    if line then
      local iscomment = string.match(line, '^#')
      local isblank = string.len(line:gsub("%s+", "")) <= 0
      if not iscomment and not isblank then
        self:push(line)
      end
    end
    cb()
  end

  local outStream = Stream:new()
  local readable = fs.createReadStream(filePath)
  -- Prolly a file not found error at this stage, pump it out
  readable:on('error', function(err) outStream:emit('error', err) end)
  readable:pipe(LineEmitter:new()):pipe(outStream)
  return outStream
end


local function _execFileToStreams(command, args, options)
  local stdout, stderr = LineEmitter:new(), LineEmitter:new()
  local child = childProcess.spawn(command, args, options)
  child.stdout:pipe(stdout)
  child.stderr:pipe(stderr)
  return child, stdout, stderr
end


local function run(command, arguments, options)
  local stream = Stream:new()
  local called, exitCode
  called = 2
  local function done()
    called = called - 1
    if called == 0 then
      if exitCode ~= 0 then
        stream:emit('error', 'Process exited with exit code ' .. exitCode)
      end
      stream:emit('end')
    end
  end
  local function onClose(_exitCode)
    exitCode = _exitCode
    done()
  end

  if not options.env then options.env = process.env end
  local child, stdout, stderr = _execFileToStreams(command, arguments, options)
  child:once('close', onClose)
  stdout:on('data', function(data) stream:emit('data', data) end):once('end', done)
  stderr:on('data', function(data) stream:emit('error', data) end)
  return stream
end


local function getInfoByVendor(options)
  local sysinfo = sigar:new():sysinfo()
  local vendor = sysinfo.vendor:lower()
  local name = sysinfo.name:lower()
  if vendor == 'red hat' then vendor = 'rhel' end
  if options[vendor] then return options[vendor] end
  if options[name] then return options[name] end
  if options.default then return options.default end
  local NilInfo = require('./nil')
  return NilInfo
end

exports.run = run
exports.read = read
exports.getInfoByVendor = getInfoByVendor
