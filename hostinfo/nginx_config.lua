--[[
Copyright 2016 Rackspace

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
local misc = require('virgo/util/misc')
local async = require('async')
local fs = require('fs')
local path = require('path')
local trim = require('virgo/util/misc').trim
--------------------------------------------------------------------------------------------------------------------

local Reader = Transform:extend()
function Reader:initialize()
  Transform.initialize(self, {objectMode = true})
end

local VersionAndConfigureOptionsReader = Reader:extend()
function VersionAndConfigureOptionsReader:_transform(line, cb)
  if line:find('^nginx') then
    self:push({version = line:match('nginx/(%d+.%d+.%d+)')})
  elseif line:find('^configure arguments') then
    local conf_args = {}
    local function addArgs(string)
      table.insert(conf_args, string)
      return ''
    end
    -- catch --opts='-otheropts'
    local line2 = line:gsub("(%-%-%S+%'(.+)%')",addArgs)
    -- catch --opts-foo_baz
    local line3 = line2:gsub('%-%-%S+', addArgs)
    -- catch --opts=opt
    line3:gsub('(%S+%=%S+)', addArgs)
    self:push({configure_arguments = conf_args})
  end
  cb()
end

local ConfArgsReader = Reader:extend()
function ConfArgsReader:_transform(line ,cb)
  if line:find('^%-%-prefix') or line:find('^%-%-conf%-path') then
    self:push({[line:match('%-%-(.+)%='):gsub('-', '_')] = line:match('%=(.+)')})
  end
  cb()
end

local ConfFileReader = Reader:extend()
function ConfFileReader:_transform(line, cb)
  if line:find('include%s') then
    self:push(line:match('include%s(.+)%;'))
  end
  cb()
end

local VhostReader = Reader:extend()
function VhostReader:initialize()
  Reader.initialize(self, {objectMode = true})
  self.locationBlock = false
end
function VhostReader:_transform(line, cb)
  if line:find('^%s*server_name') then
    self:push({domain = line:match('server_name%s(.+)%;')})
  elseif line:find('^%s*root') then
    self:push({docroot = line:match('root%s(.+)%;')})
  elseif line:find('^%s*listen') then
    self:push({listen = line:match('listen%s(.+)%;')})
  elseif line:find('^%s*location') then
    self.locationBlock = true
    self:push({location = {location = line:match('location%s(.+)%s{')}})
  end
  if self.locationBlock then
    if line:find('}') then
      self.locationBlock = false
      self:push({location = 'push'})
    else
      self:push({location = {[line:match('^%s*(%S+)%s')] = line:match('%S%s+(.+)%;')}})
    end
  end
  cb()
end

local ConfValidOrErrReader = Reader:extend()
function ConfValidOrErrReader:_transform(line, cb)
  if line:find('syntax is ok') or line:find('test is successful') then
    self:push({status = 0})
  else
    self:push({stderr = line})
  end
  cb()
end

------------------------------------------------------------------------------------------------------------------------

--[[ Checks nginx ]]--
local Info = HostInfo:extend()

function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  local errTable, outTable = {}, {}
  local nginxFullPath = '/usr/sbin/nginx' -- Checked on centos, ubuntu, red hat and debian
  local callbacked = false

  local function finalCb()
    if not callbacked then
      callbacked = true
      self:_pushParams(errTable, outTable)
      callback()
    end
  end

  local function getVersionAndConfigureOptions(cb)
    local out = {}
    local child = misc.run(nginxFullPath, {'-V'})
    local reader = VersionAndConfigureOptionsReader:new()
    -- Nginx is weird
    -- The following has been tested on centos and ubuntu cloud servers
    child:on('error', function(err)
      -- we get one err first, a table that says not implemented, then the lines we want
      -- e.g. nginx version: nginx/1.6.2 (Ubuntu)
      if type(err) == 'string' then reader:write(err) end
    end)
    child:once('end', function() reader:push(nil) end)
    reader:on('data', function(data)
      misc.safeMerge(out, data)
    end)
    reader:once('end', function()
      if out and next(out) then
        cb(out)
      else
        -- Nginx is not installed if we got no data here
        finalCb()
      end
    end)
  end

  local function getPrefixAndConfPath(conf_args, cb)
    local out, errs = {}, {}
    local confArgsReader = ConfArgsReader:new()
    confArgsReader:on('data', function(data) misc.safeMerge(out, data) end)
    confArgsReader:on('error', function(err) misc.safeMerge(errs, err) end)
    confArgsReader:once('end', function()
      if not next(out) then return finalCb() end
      cb(out)
    end)
    table.foreach(conf_args, function(_, v)
      confArgsReader:write(v)
    end)
    confArgsReader:push(nil)
  end

  local function getIncludes(conf_path, cb)
    local out, errs = {}, {}
    local readStream = misc.read(conf_path)
    local reader = ConfFileReader:new()
    readStream:pipe(reader)
    reader:on('data', function(data) misc.safeMerge(out, data) end)
    reader:on('error', function(err) misc.safeMerge(errs, err) end)
    reader:once('end', function()
      if not next(out) then return finalCb() end
      cb({includes = out})
    end)
  end

  local function getVhosts(includes, callback)
    local files, vhosts, errTable = {}, {}, {}
    table.foreach(includes, function(_, filePath)
      filePath = trim(filePath)
      -- path/*.conf || path/* -> path/
      if filePath:find('%*') then filePath = filePath:gsub('%*.*', '') end
      if filePath:sub(filePath:len()) == '/' then
        -- parse directory into list of files
        local filesInDir = fs.readdirSync(filePath)
        table.foreach(filesInDir, function(_, fileName)
          misc.safeMerge(files, path.join(filePath, fileName))
        end)
      else
        misc.safeMerge(files, filePath)
      end
    end)

    async.forEachLimit(files, 5, function(file, cb)
      local vhost, locations, location = {}, {}, {}
      local domain, listen, docroot
      local readStream = misc.read(file)
      local reader = VhostReader:new()
      reader:on('data', function(data)
        if data.domain then
          domain = data.domain
        elseif data.docroot then
          docroot = data.docroot
        elseif data.listen then
          if listen then
            if type(listen) == 'string' then
              local temp = listen
              listen = {}
              table.insert(listen, temp)
              table.insert(listen, data.listen)
            elseif type(listen) == 'table' then
              table.insert(listen, data.listen)
            end
          else
            listen = data.listen
          end
        elseif data.location then
          if data.location == 'push' then
            table.insert(locations, location)
            location = {}
          else
            misc.safeMerge(location, data.location)
          end
        end
      end)
      reader:on('error', function(err) misc.safeMerge(errTable, err) end)
      reader:once('end', function()
        domain = domain or ''
        vhost[domain] = {}
        vhost[domain]['domain'] = domain
        vhost[domain]['listen'] = listen or ''
        vhost[domain]['docroot'] = docroot or ''
        vhost[domain]['locations'] = locations or ''
        misc.safeMerge(vhosts, vhost)
        cb()
      end)
      readStream:pipe(reader)
    end,function()
      callback({vhosts = vhosts or errTable})
    end)
  end

  local function getConfValidOrErrors(cb)
    local out, err = {}, {}
    local child = misc.run(nginxFullPath, {'-t'})
    local reader = ConfValidOrErrReader:new()
    child:pipe(reader)
    child:on('error', function(err)
      reader:write(err)
    end)
    child:on('data', function(data)
      -- Nginx continues to be weird, this pipe will never get used, data comes in through err ^
      reader:write(data)
    end)
    reader:on('data', function(data)
      if data.status then
        out.status = 0
      else
        misc.safeMerge(out, data)
      end
    end)
    reader:on('error', function(data)
      misc.safeMerge(err, data)
    end)
    reader:once('end', function()
      if next(out) and not next(err) then
        cb(out)
      elseif next(err) and not next(out) then
        cb(err)
      else
        cb(out)
      end
    end)
  end

  local function compose(func, cb, args)
    if args then
      if not outTable[args] then return finalCb() end
      func(outTable[args], function(data)
        misc.safeMerge(outTable, data)
        return cb()
      end)
    else
      func(function(data)
        misc.safeMerge(outTable, data)
        return cb()
      end)
    end
  end

  async.series({
    function(cb)
      async.parallel({
        function(innerCb)
          compose(getVersionAndConfigureOptions, innerCb)
        end,
        function(innerCb)
          compose(getConfValidOrErrors, innerCb)
        end
      }, cb)
    end,
    function(cb)
      compose(getPrefixAndConfPath, cb, 'configure_arguments')
    end,
    function(cb)
      compose(getIncludes, cb, 'conf_path')
    end,
    function(cb)
      compose(getVhosts, cb, 'includes')
    end
  }, finalCb)
end

function Info:getPlatforms()
  return {'linux'}
end

function Info:getType()
  return 'NGINX_CONFIG'
end

exports.Info = Info
exports.VhostReader = VhostReader
exports.VersionAndConfigureOptionsReader = VersionAndConfigureOptionsReader
exports.ConfArgsReader = ConfArgsReader
exports.ConfFileReader = ConfFileReader
exports.ConfValidOrErrReader = ConfValidOrErrReader
