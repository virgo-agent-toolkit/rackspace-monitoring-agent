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

local table = require('table')
local async = require('async')
local childProcess = require('childprocess')
local string = require('string')
local fs = require('fs')
local LineEmitter = require('line-emitter').LineEmitter
local Transform = require('stream').Transform

local function execFileToBuffers(command, args, options, callback)
  local child, stdout, stderr, exitCode

  stdout = {}
  stderr = {}

  child = childProcess.spawn(command, args, options)
  child.stdout:on('data', function (chunk)
    table.insert(stdout, chunk)
  end)
  child.stderr:on('data', function (chunk)
    table.insert(stderr, chunk)
  end)

  async.parallel({
    function(callback)
      child.stdout:on('end', callback)
    end,
    function(callback)
      child.stderr:on('end', callback)
    end,
    function(callback)
      local onExit
      function onExit(code)
        exitCode = code
        callback()
      end

      child:on('exit', onExit)
    end
  }, function(err)
    callback(err, exitCode, table.concat(stdout, ""), table.concat(stderr, ""))
  end)
end

local function readCast(filePath, errTable, outTable, casterFunc, callback)
  -- Sanity checks
  if (type(filePath) ~= 'string') then filePath = '' end
  if (type(errTable) ~= 'table') then errTable = {} end
  if (type(outTable) ~= 'table') then outTable = {} end
  if (type(casterFunc) ~= 'function') then function casterFunc(iter, obj, line) end end
  if (type(callback) ~= 'function') then function callback() end end

  local function onExists(err, file)
    if err then
      table.insert(errTable, string.format('File not found : { fs.exists erred: %s }', err))
      return callback()
    end
    local obj = {}
    local stream = fs.createReadStream(filePath)
    local le = LineEmitter:new()
    le:on('data', function(line)
      local iscomment = string.match(line, '^#')
      local isblank = string.len(line:gsub("%s+", "")) <= 0
      if not iscomment and not isblank then
        -- split the line and assign key vals
        local iter = line:gmatch("%S+")
        casterFunc(iter, obj, line)
      end
    end)
    stream:pipe(le):once('end', function()
      -- Flatten single entry objects
      if #obj == 1 then obj = obj[1] end
      -- Dont insert empty objects into the outTable
      if next(obj) then table.insert(outTable, obj) end
      return callback()
    end)
  end
  fs.exists(filePath, onExists)
end

local function asyncSpawn(dataArr, spawnFunc, successFunc, finalCb)
  -- Sanity checks
  if type(dataArr) ~= 'table' then
    if dataArr ~= nil then
      local obj = {}
      table.insert(obj, dataArr)
      dataArr = obj
      return
    end
    dataArr = {}
  end
  if type(spawnFunc) ~= 'function' then function spawnFunc(datum) return '', {} end end
  if type(successFunc) ~= 'function' then function successFunc(data, emptyObj, datum) end end
  if type(finalCb) ~= 'function' then function finalCb(obj, errdata) end end

  -- Asynchronous spawn cps & gather data
  local obj = {}
  async.forEachLimit(dataArr, 5, function(datum, cb)
    local function _successFunc(err, exitcode, data, stderr)
      successFunc(data, obj, datum, exitcode)
      return cb()
    end
    local cmd, args = spawnFunc(datum)
    return execFileToBuffers(cmd, args, opts, _successFunc)
  end, function()
    return finalCb(obj, errdata)
  end)
end

local function execFileToStreams(command, args, options, callback)
  local stdout, stderr = LineEmitter:new(), LineEmitter:new()
  local child = childProcess.spawn(command, args, options)
  child.stdout:pipe(stdout)
  child.stderr:pipe(stderr)
  return child, stdout, stderr
end

local function streamingSpawn(cmd, args, opts, outTable, errTable, casterFunc, callback)
  -- Configure the stream handler
  local MetricsHandler = Transform:extend()
  function MetricsHandler:initialize()
    Transform.initialize(self, {objectMode = true})
    self._params = {}
  end
  function MetricsHandler:_transform(line, callback)
    casterFunc(line, callback)
  end
  local handler = MetricsHandler:new()

  -- configure the child processes ending symphony
  local exitCode, called, child, stdout, stderr
  called = 2
  if not next(opts) or not opts.env then table.insert(opts, { env = process.env }) end
  local function done()
    called = called - 1
    if called == 0 then
      if exitCode ~= 0 then
        table.insert(errTable, 'Process exited with exit code ' .. exitCode)
      end
      return callback()
    end
  end
  local function onClose(_exitCode)
    exitCode = _exitCode
    done()
  end

  -- let 'er rip
  child, stdout, stderr = execFileToStreams(cmd, args, opts)
  child:once('close', onClose)
  stdout:pipe(handler)
    :on('data', function(obj)
      table.insert(outTable, obj)
    end)
    :once('end', done)
end

exports.streamingSpawn = streamingSpawn
exports.execFileToBuffers = execFileToBuffers
exports.execFileToStreams = execFileToStreams
exports.readCast = readCast
exports.asyncSpawn = asyncSpawn
