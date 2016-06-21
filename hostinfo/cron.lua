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
local async = require('async')
local fs = require('fs')
local path = require('path')
local Transform = require('stream').Transform
local tableToString = require('virgo/util/misc').tableToString

--------------------------------------------------------------------------------------------------------------------
local Reader = Transform:extend()
function Reader:initialize()
  Transform.initialize(self, {objectMode = true})
end

function Reader:_transform(line, cb)
  local time, cmd = line:match("(@%l+)%s+(.+)")
  if time then
    self:push({
      time = time,
      command = cmd
    })
    cb()
  else
    local m, h, dom, mon, dow, command =
    line:match("(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(.+)")
    self:push({
      time = time,
      m = m,
      h = h,
      dom = dom,
      mon = mon,
      dow = dow,
      command = command
    })
    cb()
  end
end
--------------------------------------------------------------------------------------------------------------------

--[[ Cron ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  local errTable, outTable = {}, {}
  local deb = {dir = '/var/spool/cron/crontabs' }
  local rhel = {dir = '/var/spool/cron'}

  local options = {
    ubuntu = deb,
    debian = deb,
    rhel = rhel,
    centos = rhel,
    fedora = rhel,
    default = nil
  }

  local vendorInfo, dir
  vendorInfo = misc.getInfoByVendor(options)
  if not vendorInfo.dir then
    self._error = string.format("Couldn't decipher linux distro for check %s",  self:getType())
    return callback()
  end
  dir = vendorInfo.dir

  local function finalCb()
    -- We wanna be able to return empty sets for empty crontabs therefore we dont use self:_pushparams
    if errTable then
      if #errTable ~= 0 and not next(outTable) then
        self._error = tableToString(errTable, ' ')
      end
    end

    self._params = outTable
    return callback()
  end

  local function onreadDir(err, files)
    if err then misc.safeMerge(errTable, err) end
    if not files or #files == 0 then
      return finalCb()
    end
    async.forEachLimit(files, 5, function(file, cb)
      local readStream = misc.read(path.join(dir, file))
      local reader = Reader:new()
      -- Catch no file found errors
      readStream:on('error', function(err)
        misc.safeMerge(errTable, err)
        return cb()
      end)
      readStream:pipe(reader)
      reader:on('data', function(data) misc.safeMerge(outTable, data) end)
      reader:on('error', function(err) misc.safeMerge(errTable, err) end)
      reader:once('end', cb)
    end, finalCb)
  end
  fs.readdir(dir, onreadDir)
end

function Info:getType()
  return 'CRON'
end

function Info:getPlatforms()
  return {'linux'}
end

exports.Info = Info
exports.Reader = Reader
