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
]]--
local async = require('async')
local fs = require('fs')
local exists = fs.exists
local stat = fs.stat
local band = bit.band
local fmt = string.format

--[[ Check file permissions ]]--
local HostInfo = require('./base').HostInfo
local Info = HostInfo:extend()


function Info:_run(callback)
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
  local outTable = {}
  local errTable = {}

  async.forEachLimit(fileList, 5, function(file, cb)
    exists(file, function(err, data)
      if err then
        --[[This error may occasionally warn us of missing files, we can ignore it or use it upstream]]--
        table.insert(errTable, fmt('fs.exists in fileperms.lua erred: %s', err))
        return cb()
      end
      if data then
        stat(file, function(err, fstat)
          if err then
            table.insert(errTable, fmt('fs.stat in fileperms.lua erred: %s', err))
            return cb()
          end
          if fstat then
            local obj = {}
            obj.fileName = file
            --[[Check file permissions, octal: 0777]]--
            obj.octalFilePerms = band(fstat.mode, 511)
            --[[Check if the file has a sticky id, octal: 01000]]--
            obj.stickyBit = band(fstat.mode, 512) ~= 0
            --[[Check if file has a set group id, octal: 02000]]--
            obj.setgid = (band(fstat.mode, 1024) ~= 0)
            --[[Check if the file has a set user id, octal: 04000]]--
            obj.setuid = (band(fstat.mode, 2048) ~= 0)
            table.insert(outTable, obj)
            return cb()
          else
            --[[This error should not fire, ever, stat should always return data for files that exist]]--
            table.insert(errTable, 'fs.stat returned no data or false')
            return cb()
          end
        end)
      else
        return cb()
      end
    end)
  end, function()
    self:_pushParams(errTable, outTable)
    return callback()
  end)
end

function Info:getPlatforms()
  return {'linux'}
end

function Info:getType()
  return 'FILEPERMS'
end

return Info
