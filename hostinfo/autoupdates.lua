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
local misc = require('./misc')

local Reader = Transform:extend()
function Reader:initialize()
  Transform.initialize(self, {objectMode = true})
  self._pushed = false
end

local AptReader = Reader:extend()
function AptReader:_transform(line, cb)
  local _, _, key, value = line:find("(.*)%s(.*)")
  value, _ = value:gsub('"', ''):gsub(';', '')
  if key == 'APT::Periodic::Unattended-Upgrade' and value ~= 0 and not self._pushed then
    self._pushed = true
    self:push({
      update_method = 'unattended_upgrades',
      status = 'enabled'
    })
  end
  cb()
end

local YumReader = Reader:extend()
function YumReader:_transform(line, cb)
  if not self._pushed then
    self._pushed = true
    self:push({
      update_method = 'yum_cron',
      status = 'enabled'
    })
  end
  cb()
end

--[[ Are autoupdates enabled? ]]--
local Info = HostInfo:extend()

function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  local errTable, outTable = {}, {}
  local deb = {cmd = '/usr/bin/apt-config', args = {'dump'}, method = 'unattended_upgrades' }
  local rhel = {cmd = '/usr/sbin/service', args = {'yum-cron', 'status'}, method = 'yum_cron'}

  local options = {
    ubuntu = deb,
    debian = deb,
    rhel = rhel,
    centos = rhel,
    default = nil
  }
  local spawnConfig = misc.getInfoByVendor(options)
  if not spawnConfig.cmd then
    self._error = string.format("Couldn't decipher linux distro for check %s",  self:getType())
    return callback()
  end

  local cmd, args = spawnConfig.cmd, spawnConfig.args
  local method =  spawnConfig.method

  local function finalCb()
    -- no data or err recieved, so autoupdates is disabled
    if not next(errTable) and not next(outTable) then
      table.insert(self._params, {
        update_method = method,
        status = 'disabled'
      })
    else
      self:_pushParams(errTable, outTable)
    end
    return callback()
  end

  local reader = method == 'unattended_upgrades' and AptReader:new() or YumReader:new()
  local child = misc.run(cmd, args)
  child:pipe(reader)
  reader:on('error', function(err) table.insert(errTable, err) end)
  reader:on('data', function(data) table.insert(outTable, data) end)
  reader:once('end', finalCb)
end

function Info:getPlatforms()
  return {'linux'}
end

function Info:getType()
  return 'AUTOUPDATES'
end

exports.Info = Info
exports.YumReader = YumReader
exports.AptReader = AptReader