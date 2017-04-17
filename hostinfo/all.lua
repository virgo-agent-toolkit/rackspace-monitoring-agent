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
local async = require('async')
------------------------------------------------------------------------------------------------------------------------
--[[ Index of all hostinfos ]]--
local classes = {
  require('./all'),
  require('./nginx_config'),
  require('./connections'),
  require('./iptables'),
  require('./ip6tables'),
  require('./autoupdates'),
  require('./passwd'),
  require('./pam'),
  require('./cron'),
  require('./kernel_modules'),
  require('./cpu'),
  require('./disk'),
  require('./filesystem'),
  require('./filesystem_state'),
  require('./login'),
  require('./memory'),
  require('./network'),
  require('./nil'),
  require('./packages'),
  require('./procs'),
  require('./system'),
  require('./who'),
  require('./date'),
  require('./sysctl'),
  require('./sshd'),
  require('./fstab'),
  require('./fileperms'),
  require('./services'),
  require('./deleted_libs'),
  require('./cve'),
  require('./last_logins'),
  require('./remote_services'),
  require('./ip4routes'),
  require('./ip6routes'),
  require('./apache2'),
  require('./fail2ban'),
  require('./lsyncd'),
  require('./wordpress'),
  require('./magento'),
  require('./php'),
  require('./postfix'),
  require('./hostname'),
  require('./lshw')
}
------------------------------------------------------------------------------------------------------------------------

--[[ Get all hostinfo data ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  local result = {}
  local map = {}
  local types = {}
  for _, klass in pairs(classes) do
    if klass.Info then klass = klass.Info end
    if klass.getType() ~= 'ALL' then
      map[klass.getType()] = klass
      table.insert(types, klass.getType())
    end
  end

  async.forEachLimit(types, 5, function(type, cb)
    local data = {}
    local Klass = map[type]
    if Klass.Info then Klass = Klass.Info end
    local type = Klass.getType()
    local klass = Klass:new()
    klass:run(function(err)
      if err then
        data = {error = err }
      else
        data = klass:serialize()
      end
      result[type] = data
      cb()
    end)
  end, function()
    self:_pushParams(nil, result)
    callback()
  end)
end

function Info:getType()
  return 'ALL'
end

exports.Info = Info
exports.classes = classes
