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
--]]
local HostInfo = require('./base').HostInfo
local Transform = require('stream').Transform
local misc = require('virgo/util/misc')
local async = require('async')
--------------------------------------------------------------------------------------------------------------------
local Reader = Transform:extend()
function Reader:initialize()
  Transform.initialize(self, {objectMode = true})
end

function Reader:_transform(line, cb)
  -- 'root     root     root     root     1 lsyncd /etc/lsyncd/lsyncd.conf.lua' -> '/etc/lsyncd/lsyncd.conf.lua'
  local config = line:match('%slsyncd%s*(%S+)')
  if config then self:push(config) end
  cb()
end
--------------------------------------------------------------------------------------------------------------------
--[[ Checks lsyncd ]]--
local Info = HostInfo:extend()

function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  local errTable, outTable, callbacked = {}, {}, false

  local function finalCb()
    if not callbacked then
      callbacked = true
      self:_pushParams(errTable, outTable)
      callback()
    end
  end

  local function getLsyncdBin(cb)
    local options = {
      default = '/usr/bin/lsyncd'
    }
    local lsyncPath = misc.getInfoByVendor(options)
    if lsyncPath then
      cb({bin = lsyncPath})
    else
      -- Callback out of this hostinfo early
      table.insert(errTable, 'Couldnt determine OS for lsyncd')
      finalCb()
    end
  end

  local function checkLsyncIsInstalled(cb)
    local isInstalled = false
    local lsyncCmd = outTable.bin
    local child = misc.run(lsyncCmd, {'-version'})
    -- If we can get data from running the lsync cmd its installed else not
    child:on('data', function(data)
      isInstalled = true
    end)
    child:once('end', function()
      cb({installed = isInstalled})
    end)
  end

  local function getLsyncProc(cb)
    local configs, err = {}, {}
    local lsyncd_status_ok
    local counter = 2
    local function finish()
      counter = counter - 1
      if counter == 0 then cb({
        status = lsyncd_status_ok,
        config_file = configs
      })
      end
    end

    local child = misc.run('sh', {'-c', 'ps -eo euser,ruser,suser,fuser,f,cmd|grep lsync | grep -v grep'})
    local reader = Reader:new()
    child:pipe(reader)
    -- There's a good chance the user just doesnt have lsyncd, error out quickly in that case
    child:on('error', function(error)
      table.insert(errTable, 'Lsyncd not found: ' .. error)
      finalCb()
      child:emit('end')
    end)
    reader:on('data', function(data)
      configs[data] = 1 -- get unique config files only
    end)
    reader:on('error', function(error)
      table.insert(err, error)
    end)
    reader:once('end', function()
      -- flatten configs, theres usually only 1, and reorg to have uniques only and get rid of the values of 1
      if #configs == 1 then configs = configs[1] end
      local temp = {}
      table.foreach(configs, function(k)
        table.insert(temp, k)
      end)
      configs = temp
      return finish()
    end)
    child:once('end', function()
      if configs and not err then lsyncd_status_ok = true else lsyncd_status_ok = false end
      return finish()
    end)
  end

  async.parallel({
    function(cb)
      getLsyncdBin(function(out)
        misc.safeMerge(outTable, out)
        cb()
      end)
    end,
    function(cb)
      getLsyncProc(function(out)
        misc.safeMerge(outTable, out)
        cb()
      end)
    end
  }, function()
    checkLsyncIsInstalled(function(out)
      misc.safeMerge(outTable, out)
      finalCb()
    end)
  end)
end

function Info:getPlatforms()
  return {'linux'}
end

function Info:getType()
  return 'LSYNCD'
end

exports.Info = Info
exports.Reader = Reader
