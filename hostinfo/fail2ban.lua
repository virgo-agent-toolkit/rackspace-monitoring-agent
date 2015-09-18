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
local async = require('async')

local Reader = Transform:extend()
function Reader:initialize()
  Transform.initialize(self, {objectMode = true})
  self._pushed = false
end

local LogfilePathReader = Reader:extend()
function LogfilePathReader:_transform(line, cb)
  if not line:find('Current logging target is:') then
    -- e.g. '- /var/log/fail2ban.log' -> /var/log/fail2ban.log
    self:push(line:match('%s(.+)'))
  end
  cb()
end

local JailsListReader = Reader:extend()
function JailsListReader:_transform(line, cb)
  if line:find('%sJail%slist:') then
    local csvJailsList = line:match('%\t(.+)') or ''
    local jails = {}
    csvJailsList:gsub('(%a+)%p-%s-', function(c) table.insert(jails, c) end)
    self:push(jails)
  end
  cb()
end

local ActivityLogReader = Reader:extend()
function ActivityLogReader:_transform(line, cb)
  if line:find('%sBan') or line:find('%sUnban') then
    self:push(line)
  end
  cb()
end

local BannedStatsReader = Reader:extend()
function BannedStatsReader:_transform(line, cb)
  local dataTable = {}
  line:gsub("%S+", function(c) table.insert(dataTable, c) end)
  self:push({
    ip = dataTable[#dataTable],
    status = dataTable[#dataTable - 1],
    jail = dataTable[#dataTable - 2]:match('%[(.*)%]')
  })
  cb()
end

--[[ Are autoupdates enabled? ]]--
local Info = HostInfo:extend()

function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)

  local function getLogfilePath(cb)
    local errTable = {}
    local child = misc.run('fail2ban-client', {'get', 'logtarget'})
    local loglocation
    local reader = LogfilePathReader:new()
    child:pipe(reader)
    reader:on('error', function(err) misc.safeMerge(errTable, err) end)
    reader:on('data', function(data) loglocation = data end)
    reader:once('end', function()
      local alternateLoglocation = '/var/log/messages'
      if loglocation == 'SYSLOG' then
        local readStream = misc.read(loglocation)
        readStream:on('error', function(err)
          misc.safeMerge(errTable, err)
          readStream:close()
          cb({loglocation = '/var/log/syslog'}, errTable)
        end)
        readStream:on('data', function(line)
          readStream:close()
          cb({loglocation = alternateLoglocation}, errTable)
        end)
      else
        cb({loglocation = loglocation}, errTable)
      end
    end)
  end

  local function getActivityLogAndBannedStats(logfilePath, cb)
    local errTable, outTable = {}, {}
    outTable.banned, outTable.activity = {}, {}
    local counter = 500 -- lets limit this at 500
    local readStream = misc.read(logfilePath)
    local reader = ActivityLogReader:new()
    local bannedStatsReader = BannedStatsReader:new()
    -- Catch no file found errors
    readStream:on('error', function(err)
      table.insert(errTable, err)
      return cb(nil, errTable)
    end)
    readStream:pipe(reader)
    reader:on('data', function(data)
      if counter ~= 0 then
        counter = counter - 1
        table.insert(outTable.activity, data)
        bannedStatsReader:write(data)
      end
    end)
    reader:on('error', function(err) misc.safeMerge(errTable, err) end)
    reader:once('end', function()
      bannedStatsReader:emit('end')
    end)
    bannedStatsReader:on('data', function(data)
      local ban
      if outTable.banned[data.ip] then
        if outTable.banned[data.ip][data.jail] then
          ban = outTable.banned[data.ip][data.jail]
        end
      else
        ban = {count = 0, status = 'None' }
      end
      if data.status == 'Ban' then
        ban.count = ban.count + 1
      end
      ban.status = data.status
      outTable.banned[data.ip] = {}
      outTable.banned[data.ip][data.jail] = ban
    end)
    bannedStatsReader:on('error', function(err) misc.safeMerge(errTable, err) end)
    bannedStatsReader:once('end', function()
      cb(outTable, errTable)
    end)
  end

  local function getJailsList(cb)
    local errTable, outTable = {}, {}
    local child = misc.run('fail2ban-client', {'status'})
    local reader = JailsListReader:new()
    child:pipe(reader)
    reader:on('error', function(err) table.insert(errTable, err) end)
    reader:on('data', function(data)
      outTable.jails = data end)
    reader:once('end', function() cb(outTable, errTable) end)
  end

  local errTable, outTable = {}, {}

  local function finalCb()
    self:_pushParams(errTable, outTable)
    callback()
  end

  async.parallel({
    function(cb)
      getLogfilePath(function(out, err)
        misc.safeMerge(errTable, err) -- err here should be just {}
        if out.loglocation then
          getActivityLogAndBannedStats(out.loglocation, function(out, err)
            misc.safeMerge(outTable, out)
            misc.safeMerge(errTable, err)
            cb()
          end)
        else
          cb()
        end
      end)
    end,
    function(cb)
      getJailsList(function(out, err)
        misc.safeMerge(outTable, out)
        misc.safeMerge(errTable, err)
        cb()
      end)
    end
  }, finalCb)
end

function Info:getPlatforms()
  return {'linux'}
end

function Info:getType()
  return 'FAIL2BAN'
end

exports.Info = Info
exports.LogfilePathReader = LogfilePathReader
exports.JailsListReader = JailsListReader
exports.ActivityLogReader = ActivityLogReader
exports.BannedStatsReader = BannedStatsReader
