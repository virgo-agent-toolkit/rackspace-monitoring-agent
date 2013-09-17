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

local fmt = require('string').format

local async = require('async')

local run = require('./run')

local exports = {}

function runTestFile(filePath, callback)
  print(filePath)
  local status, mod = pcall(require, filePath)

  if status ~= true then
    process.stdout:write(fmt('Error loading test module [%s]: %s\n\n', filePath, mod))
    callback(err)
    return
  end

  process.stdout:write(fmt('Executing test module [%s]\n\n', filePath))
  run(nil, mod, function(err, stats)
    process.stdout:write('\n')
    callback(err, stats)
  end)
end

function runTestFiles(testFiles, options, callback)
  local failed = 0

  async.forEachSeries(testFiles, function(testFile, callback)
    runTestFile(testFile, function(err, stats)
      if err then
        callback(err)
        return
      end

      if stats then
        failed = failed + stats.failed
      end

      callback()
    end)
  end,

  function(err)
    if err then
      p(err)
      debugm.traceback(err)
    end

    callback(err, failed)
  end)
end

exports.runTestFile = runTestFile
exports.runTestFiles = runTestFiles
return exports
