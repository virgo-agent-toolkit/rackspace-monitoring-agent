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
local HostInfo = require('./base').HostInfo
local Transform = require('stream').Transform
local async = require('async')
local misc = require('./misc')
--------------------------------------------------------------------------------------------------------------------
local Reader = Transform:extend()
function Reader:initialize()
  Transform.initialize(self, {objectMode = true})
end

local VersionAndErrorReader = Reader:extend()
function VersionAndErrorReader:_transform(line, cb)
  if line:find('^HipHop') then
    self:push({
      version = {
        type = 'HipHop',
        version = line:match('%s(%d+%.%d+%.%d+)%s')
      }
    })
  elseif line:find('^PHP') then
    self:push({
      version = {
        type = 'PHP',
        version = line:match('(%d%.%S+)')
      }
    })
  elseif line:find('[wW]arning') or line:find('[Ee]rror') then
    self:push({startup_error_lines = line})
  end
  cb()
end

local ModulesReader = Reader:extend()
function ModulesReader:_transform(line, cb)
  if not line:find('%[') and line:len() > 0 then
    self:push(line)
  end
  cb()
end

local ApacheErrorReader = Reader:extend()
function ApacheErrorReader:_transform(line, cb)
  self:push({error_lines = line})
  cb()
end
--------------------------------------------------------------------------------------------------------------------
--[[ PHP
 -- We support both zend php and hiphopvm
 ]]--
local Info = HostInfo:extend()

function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)

  local function getWeblogFileLocations()
    local options = {
      ubuntu = 'apache2',
      debian = 'apache2',
      rhel = 'httpd',
      centos = 'httpd',
      default = nil
    }
    local apache2 = misc.getInfoByVendor(options)
    return string.format('/var/log/%s/*error.log*', apache2)
  end

  local function getApacheErrors(cb)
    local out, errs = {}, {}
    local child = misc.run('sh', {'-c', string.format("tail -n 5000 %s | grep 'PHP Fatal error:'", getWeblogFileLocations)})
    local reader = ApacheErrorReader:new()
    child:pipe(reader)
    reader:on('data', function(data)
      if not out.most_recent_error then out.most_recent_error = data.error_lines end
      misc.safeMerge(out, data)
    end)
    reader:on('error', function(err) misc.safeMerge(errs, err) end)
    reader:once('end', function()
      if out.error_lines then
        local errLineCount = table.getn(out.error_lines)
        if errLineCount > 0 then
          out.error_count = errLineCount
          out.errors = true
        end
      end
      cb(errs, out)
    end)
  end

  local function getPHPVersionAndErrors(cb)
    local out, errs = {}, {}
    local child = misc.run('php', {'-v'})
    local reader = VersionAndErrorReader:new()
    child:pipe(reader)
    reader:on('data', function(data) misc.safeMerge(out, data) end)
    reader:on('error', function(err) misc.safeMerge(errs, err) end)
    reader:once('end', function()
      -- check how many lines of errors we have
      if out.startup_error_lines then
        local errLineCount = table.getn(out.startup_error_lines)
        if errLineCount > 0 then
          out.startup_error_count = errLineCount
          out.startup_errors = true
        end
      end
      cb(errs, out)
    end)
  end

  local function getPhpModules(cb)
    local out, errs = {}, {}
    local child = misc.run('php', {'-m'})
    local reader = ModulesReader:new()
    child:pipe(reader)
    reader:on('data', function(data) misc.safeMerge(out, data) end)
    reader:on('error', function(err) misc.safeMerge(errs, err) end)
    reader:once('end', function()
      cb(errs, {modules = out})
    end)
  end

  local errTable, outTable = {}, {}

  local function finalCb()
    self:_pushParams(errTable, outTable)
    callback()
  end

  local function callbackTemplate(func, cb)
    func(function(errs, out)
      if not out or not next(out) then
        misc.safeMerge(errTable, errs)
      else
        misc.safeMerge(outTable, out)
      end
      cb()
    end)
  end

  outTable.log_files = getWeblogFileLocations()
  async.parallel({
    function(cb)
      callbackTemplate(getApacheErrors, cb)
    end,
    function(cb)
      callbackTemplate(getPHPVersionAndErrors, cb)
    end,
    function(cb)
      callbackTemplate(getPhpModules, cb)
    end
  }, finalCb)
end

function Info:getPlatforms()
  return {'linux'}
end

function Info:getType()
  return 'PHP'
end

exports.Info = Info
exports.VersionAndErrorReader = VersionAndErrorReader
exports.ModulesReader = ModulesReader
exports.ApacheErrorReader = ApacheErrorReader
