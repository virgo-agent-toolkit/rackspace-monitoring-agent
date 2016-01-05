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
local HostInfo = require('./base').HostInfo
local Transform = require('stream').Transform
local async = require('async')
local join = require('path').join
local walk = require('luvit-walk').readdirRecursive
local misc = require('./misc')
local filter = {
  inet_interfaces = true, -- Postfix Listening On Addresses
  inet_protocols = true, -- IP protocols in use
  myhostname = true, -- Postfix Hostname
  mydomain = true, -- Postfix Domain Name
  mydestination = true, -- Postfix Final Destinations
  mynetworks = true, -- Postfix Trusted Client Networks
  myorigin = true, -- Postfix Origin Address
  alias_database = true, -- Postfix Aliases Database
  config_directory = true, -- Postfix Configuration Directory
  queue_directory = true, -- Postfix Queue Directory
  mail_version = true, -- Version of postconf we have
}
--------------------------------------------------------------------------------------------------------------------
local Reader = Transform:extend()
function Reader:initialize()
  Transform.initialize(self, {objectMode = true})
end

local ProcessReader = Reader:extend()
function Reader:_transform(line, cb)
  self:push({
    PID = line:match('^%d+'),
    process = line:match('%S+$')
  })
  cb()
end

local ConfigReader = Reader:extend()
function ConfigReader:_transform(line, cb)
  local key, value = line:match('(.*)%s%=%s(.*)')
  if filter[key] then self:push({[key] = value}) end
  cb()
end

--------------------------------------------------------------------------------------------------------------------
--[[ Postfix ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  local function findPostfixProcess(cb)
    local errs, out = {}, {}
    local child = misc.run('pgrep', {'-a', 'master'})
    local reader = ProcessReader:new()
    child:pipe(reader)
    reader:on('data', function(data) misc.safeMerge(out, data) end)
    reader:on('error', function(err) misc.safeMerge(errs, err) end)
    reader:once('end', function()
      if not out or not next(out) then
        cb(nil, {
          process = {
            process = 'Postfix is not running'
          }
        })
      else
        cb(errs, {process = out})
      end
    end)
  end

  local function getPostfixConfig(cb)
    local errs, out = {}, {}
    local child = misc.run('postconf')
    local reader = ConfigReader:new()
    child:pipe(reader)
    reader:on('data', function(data) misc.safeMerge(out, data) end)
    reader:on('error', function(err) misc.safeMerge(errs, err) end)
    reader:once('end', function()
      cb(errs, {current_configuration = out})
    end)
  end

  local function getMailQueueSize(queue_directory, cb)
    if not queue_directory or not type(queue_directory) == 'string' then
      return cb('No mail queue directory found')
    end
    local out, errs = {}, {}
    local queues = {
      'incoming', -- Incoming Mail
      'active', -- Active Mail
      'deferred', -- Deferred Mail
      'bounce', -- Bounced Mail
      'hold', -- Hold Mail
      'corrupt', -- Corrupt Mail
    }
    async.forEach(queues, function(queue, forEachCb)
      local path = join(queue_directory, queue)
      walk(path, function(err, files)
        if err or not files or not next(files) then
          misc.safeMerge(errs, err)
          out[queue] = 0
        else
          out[queue] = #files
        end
        forEachCb()
      end)
    end, function()
      cb(errs, {mail_queue_size = out})
    end)
  end

  local errTable, outTable = {}, {}

  local function finalCb()
    self:_pushParams(errTable, outTable)
    callback()
  end

  async.parallel({
    function(cb)
      findPostfixProcess(function(err, out)
        misc.safeMerge(errTable, err)
        misc.safeMerge(outTable, out)
        cb()
      end)
    end,
    function(cb)
      getPostfixConfig(function(err, out)
        misc.safeMerge(errTable, err)
        misc.safeMerge(outTable, out)
        cb()
      end)
    end
  }, function()
    getMailQueueSize(outTable.current_configuration.queue_directory, function(err, out)
      misc.safeMerge(errTable, err)
      misc.safeMerge(outTable, out)
      finalCb()
    end)
  end)
end

function Info:getPlatforms()
  return {'linux'}
end

function Info:getType()
  return 'POSTFIX'
end

exports.Info = Info
exports.ProcessReader = ProcessReader
exports.ConfigReader = ConfigReader
