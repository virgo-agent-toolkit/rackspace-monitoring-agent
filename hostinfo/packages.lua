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
local misc = require('./misc')
local Transform = require('stream').Transform

--------------------------------------------------------------------------------------------------------------------
local Reader = Transform:extend()

function Reader:initialize()
  Transform.initialize(self, {objectMode = true})
end

local LinuxReader = Reader:extend()
function LinuxReader:_transform(line, cb)
  line = line:gsub("^%s*(.-)%s*$", "%1")
  local _, _, key, value = line:find("(.*)%s(.*)")
  if key then self:push({ name = key, version = value }) end
  cb()
end

local MacReader = Reader:extend()
function MacReader:_transform(line, cb)
  self:push({ name = line, version = 'unknown' })
  cb()
end

--------------------------------------------------------------------------------------------------------------------
--[[ Packages ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  local errTable, outTable = {}, {}
  local deb = {cmd = 'dpkg-query', args = {'-W'}}
  local rhel =  {cmd = 'rpm', args = {'-qa', '--queryformat', '%{NAME} %{VERSION}-%{RELEASE}\n'}}

  local options = {
    ubuntu = deb,
    debian = deb,
    rhel = rhel,
    centos = rhel,
    fedora = rhel,
    macosx = {cmd = 'brew', args = {'leaves'}},
    default = nil
  }

  local spawnConfig = misc.getInfoByVendor(options)
  if not spawnConfig.cmd then
    self._error = string.format("Couldn't decipher linux distro for check %s",  self:getType())
    return callback()
  end
  local cmd, args = spawnConfig.cmd, spawnConfig.args

  local function finalCb()
    self:_pushParams(errTable, outTable)
    return callback()
  end

  local child = misc.run(cmd, args)
  local reader = cmd == 'brew' and MacReader:new() or LinuxReader:new()
  child:pipe(reader)
  reader:on('data', function(data) table.insert(outTable, data) end)
  reader:on('error', function(data) table.insert(errTable, data) end)
  reader:once('end', finalCb)
end

function Info:getPlatforms()
  return {'linux', 'darwin'}
end

function Info:getType()
  return 'PACKAGES'
end

exports.Info = Info
exports.MacReader = MacReader
exports.LinuxReader = LinuxReader
