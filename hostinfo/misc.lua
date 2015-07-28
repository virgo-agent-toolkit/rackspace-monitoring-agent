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

  local obj = {}
  fs.exists(filePath, function(err, file)
    if err then
      table.insert(errTable, string.format('File not found : { fs.exists erred: %s }', err))
      return callback()
    end
    if file then
      fs.readFile(filePath, function(err, data)

        if err then
          table.insert(errTable, string.format('File couldnt be read : { fs.readline erred: %s }', err))
          return callback()
        end

        for line in data:gmatch("[^\r\n]+") do
          local iscomment = string.match(line, '^#')
          local isblank = string.len(line:gsub("%s+", "")) <= 0

          if not iscomment and not isblank then
            -- split the line and assign key vals
            local iter = line:gmatch("%S+")
            casterFunc(iter, obj, line)
          end
        end

        -- Flatten single entry objects
        if #obj == 1 then obj = obj[1] end
        -- Dont insert empty objects into the outTable
        if next(obj) then table.insert(outTable, obj) end

        return callback()
      end)
    else
      table.insert(errTable, 'file not found')
      return callback()
    end

  end)
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


return {execFileToBuffers=execFileToBuffers, readCast=readCast, asyncSpawn=asyncSpawn}
