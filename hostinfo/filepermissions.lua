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

local forEachLimit = require('async').forEachLimit
local table = require('table')
local os = require('os')
local spawn = require('childprocess').spawn

--[[ Filepermissions Variables ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:run(callback)
  if os.type() ~= 'Linux' then
    self._error = 'Unsupported OS for Filepermissions'
    callback()
    return
  end

  local obj = {}

  local files = {
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
    '/var/run/php-fpm.sock',
  }

  forEachLimit(files, 5, function(file, callback)
    local child
    child = spawn('stat', {'-L', '-c', '"%a"', file}, {})

    local data = ''
    child.stdout:on('data', function(chunk)
      data = data .. chunk
    end)

    local errdata = ''
    child.stderr:on('data', function(chunk)
      errdata = errdata .. chunk
    end)

    child:on('error', function(err)
      errdata = err
    end)

    child:on('exit', function(exit_code)
      if exit_code ~= 0 then
        return
      end
    end)

    child.stdout:on('end', function()
      if data ~= nil and data ~= '' then
        obj[file] = data:gsub('[\n|"]','')
      end
      if errdata ~= nil and errdata ~= '' then
        obj[file] = errdata:gsub('[\n|"]','')
      end
      callback()
    end)
  end, function()
    table.insert(self._params, obj)
    callback()
  end)
end

function Info:getType()
  return 'FILEPERMISSIONS'
end

return Info
