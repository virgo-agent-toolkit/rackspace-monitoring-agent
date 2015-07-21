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
local misc = require('virgo/util/misc')
local async = require('async')
local childProcess = require('childprocess')
local string = require('string')
local fs = require('fs')

local function execFileToBuffers(command, args, options, callback)
  local child, stdout, stderr, exitCode

  stdout = {}
  stderr = {}
  callback = misc.fireOnce(callback)

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

local function readCast(filePath, errHandler, outTable, casterFunc, callback)
  local obj = {}
  fs.exists(filePath, function(err, file)

    if err then
      table.insert(errHandler, string.format('fs.exists in fstab.lua erred: %s', err))
      return callback()
    end
    if file then
      fs.readFile(filePath, function(err, data)

        if err then
          table.insert(errHandler, string.format('fs.readline erred: %s', err))
          return callback()
        end

        for line in data:gmatch("[^\r\n]+") do
          local iscomment = string.match(line, '^#')
          local isblank = string.len(line:gsub("%s+", "")) <= 0

          if not iscomment and not isblank then
            -- split the line and assign key vals
            local iter = line:gmatch("%S+")
            casterFunc(iter, obj)
          end
        end

        -- Flatten single entry objects
        if #obj == 1 then obj = obj[1] end
        table.insert(outTable, obj)
        return callback()

      end)
    else
      table.insert(errHandler, 'file not found')
      return callback()
    end

  end)
end

return {execFileToBuffers=execFileToBuffers, readCast=readCast}
