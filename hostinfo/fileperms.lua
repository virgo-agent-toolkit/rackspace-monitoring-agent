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
local table = require('table')
local los = require('los')
local async = require('async')
local exists = require('fs').exists
local stat = require('fs').stat
local band = bit.band
local fmt = require('string').format

--[[ Check file permissions ]]--
local HostInfo = require('./base').HostInfo
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  if los.type() ~= 'linux' then
    self._error = 'Unsupported OS for file permissions'
    return callback()
  end

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
  local obj = {}
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
            obj[file] = {}
            --[[Check file permissions, octal: 0777]]--
            obj[file]['octalFilePerms'] = band(fstat.mode, 511)
            --[[Check if the file has a sticky id, octal: 01000]]--
            obj[file]['stickyBit'] = band(fstat.mode, 512) ~= 0
            --[[Check if file has a set group id, octal: 02000]]--
            obj[file]['setgid'] = (band(fstat.mode, 1024) ~= 0)
            --[[Check if the file has a set user id, octal: 04000]]--
            obj[file]['setuid'] = (band(fstat.mode, 2048) ~= 0)
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
    if obj ~= nil then
      table.insert(self._params, {
        data = obj,
        warnings = errTable
      })
    else
      self._error = errTable
    end
    return callback()
  end)

end

function Info:getType()
  return 'FILEPERMS'
end

return Info
