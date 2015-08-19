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

local los = require('los')
local readCast = require('./misc').readCast
local async = require('async')
local fs = require('fs')
local path = require('path')
local sigar = require('sigar')

--[[ Pluggable auth modules ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  if los.type() ~= 'linux' then
    self._error = 'Unsupported OS for pluggable auth module definitions'
    return callback()
  end

  local cdir, vendor, errTable
  vendor = sigar:new():sysinfo().vendor:lower()
  errTable = {}
  if vendor == 'ubuntu' or vendor == 'debian' then
    cdir = '/var/spool/cron/crontabs'
  elseif vendor == 'rhel' or vendor == 'centos' then
    cdir = '/var/spool/cron'
  else
    self._error = 'Could not determine OS'
    return callback()
  end

  local function parseLine(iter, obj, line)
    local time, command = line:match("(@%l+)%s+(.+)")
    if time then
      return table.insert(obj, {
        time = time,
        command = command
      })
    end
    local pattern = "(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(.+)"
    local m,h, dom, mon, dow
    m, h, dom, mon, dow, command = line:match(pattern)
    return table.insert(obj, {
      time = time,
      m = m,
      h = h,
      dom = dom,
      mon = mon,
      dow = dow,
      command = command
    })
  end

  fs.readdir(cdir, function(err, files)
    if err then
      self._error = err
      return callback()
    end
    async.forEachLimit(files, 5, function(file, cb)
      readCast(path.join(cdir, file), errTable, self._params, parseLine, cb)
    end, function()
      if self._params ~= nil then
        table.insert(self._params, {
          warnings = errTable
        })
      else
        self._error = errTable
      end
      return callback()
    end)
  end)
end

function Info:getType()
  return 'CRON'
end

return Info
