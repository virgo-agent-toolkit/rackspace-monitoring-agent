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
local SubProcCheck = require('./base').SubProcCheck
local CheckResult = require('./base').CheckResult
local hostname = require('../hostname')
local Emitter = require('core').Emitter
local bind = require('utils').bind
local async = require('async')
local fs = require('fs')
local spawn = require('childprocess').spawn
local LineEmitter = require('line-emitter').LineEmitter
local misc = require('virgo/util/misc')

local CONFIG_FILE = '/opt/rackspace/host.conf'
local OVS_PID = '/var/run/openvswitch/ovs-vswitchd.pid'

local function parseIni(filename)
  local t = { DEFAULT = {} }
  local section = 'DEFAULT'
  local data, err = fs.readFileSync(filename)
  if err then return nil, err end
  for line in data:gmatch("([^\n]*)\n") do
    local s = line:match("^%[([^%]]+)%]$")
    if s then
      section = s
      t[section] = t[section] or {}
    end
    local key, value = line:match("^(.+)%s-=%s-(.+)$")
    if key and value then
      if tonumber(value) then value = tonumber(value) end
      if value == "true" then value = true end
      if value == "false" then value = false end
      t[section][key] = value
    end
  end
  return t
end

-- **************************************************************************

local Deputy = Emitter:extend()
function Deputy:initialize()
  self.le = LineEmitter:new()
  self.le:on('data', function(line) self:emit('line', line) end)
end

function Deputy:run(cmd, args)
  local onError, onStdout, onStdoutEnd, onExit, onDone
  local callbackCount = 2
  local child = spawn(cmd, args)
  function onDone()
    if callbackCount ~= 0 then return end
    self:emit('done')
  end
  function onError(err)
    self:emit('error', err)
  end
  function onExit()
    callbackCount = callbackCount - 1
    onDone()
  end
  function onStdout(chunk)
    self.le:write(chunk)
  end
  function onStdoutEnd()
    self.le:write()
    callbackCount = callbackCount - 1
    onDone()
  end
  child.stdout:on('data', onStdout)
  child.stdout:on('end', onStdoutEnd)
  child:on('error', onError)
  child:on('exit', onExit)
end

-- **************************************************************************

local RaxxenCheck = SubProcCheck:extend()
function RaxxenCheck:initialize(params)
  SubProcCheck.initialize(self, params)
end

function RaxxenCheck:getType()
  return 'agent.raxxen'
end

function RaxxenCheck:_collectInstanceCount(checkResult, prefix, callback)
  local count = 0
  local d = Deputy:new()
  d:run('/usr/sbin/xl', { 'list' })
  d:on('line', function(line)
    if line:find('instance') then count = count + 1 end
  end)
  d:on('done', function()
    checkResult:addMetric(prefix .. 'instance_count', nil, 'uint64', count)
    callback()
  end)
  d:on('error', function()
    checkResult:addMetric(prefix .. 'instance_count', nil, 'uint64', 0)
    callback()
  end)
end

function RaxxenCheck:_collectOvsCPUUsage(checkResult, prefix, callback)
  local usage = 0
  local pid, err = fs.readFileSync(OVS_PID)
  if err then return callback(err) end
  local function onLine(line)
    line = misc.trim(line)
    if line:find('^' .. pid) then
      line = misc.split(line)
      usage = tonumber(line[9])
    end
  end
  local d = Deputy:new()
  d:run('top', { '-bn1', '-p', misc.trim(pid) })
  d:on('line', onLine)
  d:on('done', function()
    checkResult:addMetric(prefix .. 'ovs_cpu', nil, 'double', usage)
    callback()
  end)
  d:on('error', function()
    checkResult:addMetric(prefix .. 'ovs_cpu', nil, 'double', 0)
    callback()
  end)
end

function RaxxenCheck:_collectDataPathStats(checkResult, prefix, callback)
  local datapaths = {}
  local current_datapath = ''
  local function onLine(line)
    if line:byte(1) ~= 0x09 then
      current_datapath = misc.trim(line):gsub(":", "")
      datapaths[current_datapath] = {}
    else
      line = misc.trim(line)
      local key, value = line:match("([^:]+):(.+)")
      if key == 'lookups' or key == 'flows' or key == 'masks' then
        value = misc.trim(value)
        if key == 'flows' then
          datapaths[current_datapath][key] = value
        else
          local t = {}
          for _, v in pairs(misc.split(value)) do
            local kv, vv = v:match("([^:]+):(.+)")
            t[kv] = vv
          end
          datapaths[current_datapath][key] = t
        end
      end
    end
  end
  local function onDone()
    local path = datapaths['system@ovs-system']
    if path then
      pcall(function()
        checkResult:addMetric(prefix .. 'ovs_datapath.flow_count', nil, 'uint64', path.flows)
        checkResult:addMetric(prefix .. 'ovs_datapath.hit', nil, 'uint64', path.lookups.hit)
        checkResult:addMetric(prefix .. 'ovs_datapath.missed', nil, 'uint64', path.lookups.missed)
        checkResult:addMetric(prefix .. 'ovs_datapath.lost', nil, 'uint64', path.lookups.lost)
        checkResult:addMetric(prefix .. 'ovs_datapath_masks.hit', nil, 'uint64', path.masks.hit)
        checkResult:addMetric(prefix .. 'ovs_datapath_masks.total', nil, 'uint64', path.masks.total)
        checkResult:addMetric(prefix .. 'ovs_datapath_masks.hit_per_pkt', nil, 'uint64', path.masks['hit/pkt'])
      end)
    end
    callback()
  end
  local d = Deputy:new()
  d:run('ovs-dpctl', { 'show' })
  d:on('line', onLine)
  d:on('done', onDone)
  d:on('error', callback)
end

function RaxxenCheck:_runCheckInChild(callback)
  local checkResult = CheckResult:new(self, {})
  local config, err = parseIni(CONFIG_FILE)
  if err then
    checkResult:setError(tostring(err))
    return callback(checkResult)
  end
  local region = config['DEFAULT']['ENV_NAME']
  local cell = config['DEFAULT']['cell']
  local prefix = ''
  if region and cell then
    prefix = region .. '.' .. cell .. '.' .. hostname() .. '.'
    prefix = prefix:gsub('-', '_')
  end

  async.series({
    -- Gather Instance Count
    bind(self._collectInstanceCount, self, checkResult, prefix),
    -- Gather OVS CPU Usage
    bind(self._collectOvsCPUUsage, self, checkResult, prefix),
    -- Gather DataPath Stats
    bind(self._collectDataPathStats, self, checkResult, prefix),
  }, function(err)
    if err then
      checkResult:setError(tostring(err))
    end
    callback(checkResult)
  end)
end

exports.RaxxenCheck = RaxxenCheck
