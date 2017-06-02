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
local table = require('table')
local fs = require('fs')
local async = require('async')
local fmt = string.format

--[[ Installed services info ]]--
local Info = HostInfo:extend()


function Info:_run(callback)
  local init, initd, system, systemv, systemd, errTable, outTable
  init = '/etc/init/'
  initd = '/etc/init.d'
  system = '/usr/lib/systemd/system'
  systemd = {
    '/etc/systemd/system/multi-user.target.wants/',
    '/etc/systemd/system/basic.target.wants/'
  }
  systemv = '/etc/rc3.d'
  errTable, outTable = {}, {}

  local function scanDir(path, key, cb)
    fs.readdir(path, function(err, data)
      if err then
        table.insert(errTable, fmt('Error reading services directory: %s . You can probably ignore this error', err))
        return cb()
      end
      outTable[key] = data
      return cb()
    end)
  end

  async.parallel({
    function(cb)
      scanDir(init, 'init', cb)
    end,
    function(cb)
      scanDir(initd, 'initd', cb)
    end,
    function(cb)
      scanDir(system, 'system', cb)
    end,
    function(cb)
      scanDir(systemv, 'systemv', cb)
    end,
    function(cb)
      scanDir(systemd[1], 'systemd', cb)
    end,
    function(cb)
      scanDir(systemd[2], 'systemd', cb)
    end
  }, function()
    self:_pushParams(errTable, outTable)
    return callback()
  end)
end

function Info:getType()
  return 'SERVICES'
end

function Info:getPlatforms()
  return {'linux'}
end

return Info
