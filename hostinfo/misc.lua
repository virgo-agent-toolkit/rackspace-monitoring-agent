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
local async = require('async')
local childProcess = require('childprocess')
local fs = require('fs')
local sigar = require('sigar')
local string = require('string')
local table = require('table')

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

local function readCast(filePath, casterFunc, callback)
  -- Sanity checks
  assert(filePath, 'Parameter missing: (filePath) file to read undefined')
  assert(casterFunc, 'Parameter missing: (casterFunc) Function to call per line to process data not specified')
  assert(callback, 'Parameter missing: (callback) final returning callback')
  if (type(filePath) ~= 'string') then filePath = '' end
  if (type(casterFunc) ~= 'function') then function casterFunc(iter, line) end end
  if (type(callback) ~= 'function') then function callback() end end

  local errTable = {}
  local function onExists(err, file)
    if err then
      table.insert(errTable, string.format('File not found : { fs.exists erred: %s }', err))
      return callback(errTable)
    end
    local stream = fs.createReadStream(filePath)
    local le = LineEmitter:new()
    le:on('data', function(line)
      local iscomment = string.match(line, '^#')
      local isblank = string.len(line:gsub("%s+", "")) <= 0
      if not iscomment and not isblank then
        -- split the line and assign key vals
        local iter = line:gmatch("%S+")
        casterFunc(iter, line)
      end
    end)
    stream:pipe(le):once('end', function()
      return callback(errTable)
    end)
  end
  fs.exists(filePath, onExists)
end

local function execFileToStreams(command, args, options, callback)
  local stdout, stderr = LineEmitter:new(), LineEmitter:new()
  local child = childProcess.spawn(command, args, options)
  child.stdout:pipe(stdout)
  child.stderr:pipe(stderr)
  return child, stdout, stderr
end

local function asyncSpawn(dataArr, spawnFunc, successFunc, finalCb)
  -- Sanity checks
  assert(dataArr, 'Parameter missing: (dataArr) Data array to loop over not specified')
  assert(spawnFunc, 'Parameter missing: (spawnFunc) function to generate args for spawner not specified')
  assert(successFunc, 'Parameter missing: (successFunc) Function to call per line to process data not specified')
  assert(finalCb, 'Parameter missing: (finalCb) final returning callback')
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
  if type(successFunc) ~= 'function' then function successFunc(data, datum) end end
  if type(finalCb) ~= 'function' then function finalCb(errdata) end end
  local errTable = {}

  -- Asynchronous spawn cps & gather data
  async.forEachLimit(dataArr, 5, function(datum, cb)
    local child, stdout, stderr, cmd, args, exitCode, called
    called = 2
    local function done()
      called = called - 1
      if called == 0 then
        if exitCode ~= 0 then
          table.insert(errTable, 'Process exited with exit code ' .. exitCode)
        end
        cb()
      end
    end
    local function onClose(_exitCode)
      exitCode = _exitCode
      done()
    end

    cmd, args = spawnFunc(datum)
    child, stdout, stderr = execFileToStreams(cmd,
      args,
      { env = process.env })
    child:once('close', onClose)
    stdout
    :on('data', function(data)
      successFunc(data, datum)
    end)
    :once('end', done)
    --return execFileToBuffers(cmd, args, opts, _successFunc)
  end, function()
    return finalCb(err)
  end)
end


local function getInfoByVendor(options)
  local sysinfo = sigar:new():sysinfo()
  local vendor = sysinfo.vendor:lower()
  local name = sysinfo.name:lower()
  if options[vendor] then return options[vendor] end
  if options[name] then return options[name] end
  if options.default then return options.default end
  local NilInfo = require('./nil')
  return NilInfo
end


exports.execFileToBuffers = execFileToBuffers
exports.execFileToStreams = execFileToStreams
exports.getInfoByVendor = getInfoByVendor
exports.readCast = readCast
exports.asyncSpawn = asyncSpawn
