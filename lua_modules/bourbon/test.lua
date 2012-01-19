#!/usr/bin/env luvit

local FS = require('fs')
local Path = require('path')
local bourbon = require('./')
local async = require('async')

local fmt = require('string').format

local TEST_PATH = './tests'

local function runit(filename, callback)
  local modname = './' .. Path.join(TEST_PATH, filename)
  process.stdout:write(fmt('Executing test module [%s]\n\n', modname))
  bourbon.run(nil, require(modname), function(err)
    process.stdout:write('\n')
    callback()
  end)
end

FS.readdir(TEST_PATH, function(err, files)
  if err then
    p(err)
    return
  end
  async.forEachSeries(files, runit, function(err) end)
end)

