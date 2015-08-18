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
]]--

--[[ Check file permissions ]]--
local HostInfo = require('./base').HostInfo
local table = require('table')
local async = require('async')
local exists = require('fs').exists
local stat = require('fs').stat
local band = bit.band
local fmt = require('string').format

local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:run(callback)
  if self:isRestrictedPlatform() then return callback() end

  local fileList = {
    '/etc/grub.conf',
    '/boot/grub/grub.cfg',
    '/etc/passwd',
    '/etc/shadow',
    '/etc/hosts.allow',
    '/etc/hosts.deny',
    '/etc/anacrontab',
    '/etc/crontab',
    '/etc/cron.hourly',
    '/etc/cron.daily',
    '/etc/cron.weekly',
    '/etc/cron.monthly',
    '/etc/cron.d',
    '/etc/ssh/sshd_config',
    '/etc/gshadow',
    '/etc/group',
    '/etc/login.defs',
    '/var/run/php-fpm.sock'
  }
  local errTable = {}
  local filePermsTable = {}

  async.forEachLimit(fileList, 5, function(file, cb)
    exists(file, function(err, data)
      if err then
        --[[This error may occasionally warn us of missing files, we can ignore it or use it upstream]]--
        table.insert(errTable, fmt('fs.exists in fileperms.lua erred: %s', err))
        return cb()
      end
      stat(file, function(err, fstat)
        if err or not fstat then
          table.insert(errTable, fmt('fs.stat in fileperms.lua erred: %s', err))
          return cb()
        end
        local obj = {}
        local mode = fstat.mode
        obj['name'] = file
        --[[Check file permissions, octal: 0777]]--
        obj['octalFilePerms'] = band(mode, 511)
        --[[Check if the file has a sticky id, octal: 01000]]--
        obj['stickyBit'] = band(mode, 512) ~= 0
        --[[Check if file has a set group id, octal: 02000]]--
        obj['setgid'] = (band(mode, 1024) ~= 0)
        --[[Check if the file has a set user id, octal: 04000]]--
        obj['setuid'] = (band(mode, 2048) ~= 0)
        table.insert(filePermsTable, obj)
        return cb()
      end)
    end)
  end, function()
    self:pushParams(filePermsTable, errTable)
    return callback()
  end)
end

function Info:getRestrictedPlatforms()
  return {'win32'}
end

function Info:getType()
  return 'FILEPERMS'
end

return Info
