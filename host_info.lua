--[[
Copyright 2012 Rackspace

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

local Object = require('core').Object
local JSON = require('json')

local fs = require('fs')
local misc = require('/util/misc')
local os = require('os')
local table = require('table')
local vutils = require('virgo_utils')

local sigarCtx = require('/sigar').ctx
local sigarutil = require('/util/sigar')

--[[ HostInfo ]]--
local HostInfo = Object:extend()
function HostInfo:initialize()
  self._params = {}
end

function HostInfo:serialize()
  return {
    metrics = self._params,
    timestamp = vutils.gmtNow()
  }
end

--[[ NilInfo ]]--
local NilInfo = HostInfo:extend()

--[[ CPUInfo ]]--
local CPUInfo = HostInfo:extend()
function CPUInfo:initialize()
  HostInfo.initialize(self)
  local cpus = sigarCtx:cpus()
  for i=1, #cpus do
    local obj = {}
    local info = cpus[i]:info()
    local data = cpus[i]:data()
    local name = 'cpu.' .. i - 1
    local data_fields = {
      'idle',
      'irq',
      'nice',
      'soft_irq',
      'stolen',
      'sys',
      'total',
      'user',
      'wait'
    }
    local info_fields = {
      'mhz',
      'model',
      'total_cores',
      'total_sockets',
      'vendor'
    }

    for _, v in pairs(data_fields) do
      obj[v] = data[v]
    end
    for _, v in pairs(info_fields) do
      obj[v] = info[v]
    end

    obj['name'] = name
    table.insert(self._params, obj)
  end
end

--[[ DiskInfo ]]--
local DiskInfo = HostInfo:extend()
function DiskInfo:initialize()
  HostInfo.initialize(self)
  local disks = sigarutil.diskTargets(sigarCtx)
  local usage_fields = {
    'read_bytes',
    'reads',
    'rtime',
    'time',
    'write_bytes',
    'writes',
    'wtime'
  }
  for i=1, #disks do
    local name = disks[i]:name()
    local usage = disks[i]:usage()
    if name and usage then
      local obj = {}
      for _, v in pairs(usage_fields) do
        obj[v] = usage[v]
      end
      obj['name'] = name
      table.insert(self._params, obj)
    end
  end
end

--[[ MemoryInfo ]]--
local MemoryInfo = HostInfo:extend()
function MemoryInfo:initialize()
  HostInfo.initialize(self)
  local swapinfo = sigarCtx:swap()
  local data = sigarCtx:mem()
  local data_fields = {
    'actual_free',
    'actual_used',
    'free',
    'free_percent',
    'ram',
    'total',
    'used',
    'used_percent'
  }
  local swap_metrics = {
    'total',
    'used',
    'free',
    'page_in',
    'page_out'
  }
  if data then
    for _, v in pairs(data_fields) do
      self._params[v] = data[v]
    end
  end
  if swapinfo then
    for _, k in pairs(swap_metrics) do
      self._params['swap_' .. k] = swapinfo[k]
    end
  end
end

--[[ NetworkInfo ]]--
local NetworkInfo = HostInfo:extend()
function NetworkInfo:initialize()
  HostInfo.initialize(self)
  local netifs = sigarCtx:netifs()
  for i=1,#netifs do
    local info = netifs[i]:info()
    local usage = netifs[i]:usage()
    local name = info.name
    local obj = {}

    local info_fields = {
      'address',
      'address6',
      'broadcast',
      'flags',
      'hwaddr',
      'mtu',
      'name',
      'netmask',
      'type'
    }
    local usage_fields = {
      'rx_packets',
      'rx_bytes',
      'rx_errors',
      'rx_overruns',
      'rx_dropped',
      'tx_packets',
      'tx_bytes',
      'tx_errors',
      'tx_overruns',
      'tx_dropped',
      'tx_collisions',
      'tx_carrier',
    }

    if info then
      for _, v in pairs(info_fields) do
        obj[v] = info[v]
      end
    end
    if usage then
      for _, v in pairs(usage_fields) do
        obj[v] = usage[v]
      end
    end
    obj['name'] = name
    table.insert(self._params, obj)
  end
end

--[[ Process Info ]]--
local ProcessInfo = HostInfo:extend()
function ProcessInfo:initialize()
  HostInfo.initialize(self)
  local procs = sigarCtx:procs()

  for i=1, #procs do
    local pid = procs[i]
    local proc = sigarCtx:proc(pid)
    local obj = {}
    obj.pid = pid

    local t, msg = proc:exe()
    if t then
      local exe_fields = {
        'name',
        'cwd',
        'root'
      }
      for _, v in pairs(exe_fields) do
        obj['exe_' .. v] = t[v]
      end
    end

    t, msg = proc:time()
    if t then
      local time_fields = {
        'start_time',
        'user',
        'sys',
        'total'
      }
      for _, v in pairs(time_fields) do
        obj['time_' .. v] = t[v]
      end
    end

    t, msg = proc:state()
    if t then
      local proc_fields = {
        'name',
        'ppid',
        'priority',
        'nice',
        'threads'
      }
      for _, v in pairs(proc_fields) do
        obj['state_' .. v] = t[v]
      end
    end

    t, msg = proc:mem()
    if t then
      local memory_fields = {
        'size',
        'resident',
        'share',
        'major_faults',
        'minor_faults',
        'page_faults'
      }
      for _, v in pairs(memory_fields) do
        obj['memory_' .. v] = t[v]
      end
    end

    t, msg = proc:cred()
    if t then
      local cred_fields = {
        'user',
        'group',
      }
      for _,v in pairs(cred_fields) do
        obj['cred_' .. v] = t[v]
      end
    end
    table.insert(self._params, obj)
  end
end

--[[ Filesystem Info ]]--
local FilesystemInfo = HostInfo:extend()
function FilesystemInfo:initialize()
  HostInfo.initialize(self)
  local fses = sigarCtx:filesystems()
  for i=1, #fses do
    local obj = {}
    local fs = fses[i]
    local info = fs:info()
    local usage = fs:usage()
    if info then
      local info_fields = {
        'dir_name',
        'dev_name',
        'sys_type_name',
        'options',
      }
      for _, v in pairs(info_fields) do
        obj[v] = info[v]
      end
    end

    if usage then
      local usage_fields = {
        'total',
        'free',
        'used',
        'avail',
        'files',
        'free_files',
      }
      for _, v in pairs(usage_fields) do
        obj[v] = usage[v]
      end
    end

    table.insert(self._params, obj)
  end
end

--[[ System Info ]]--
local SystemInfo = HostInfo:extend()
function SystemInfo:initialize()
  HostInfo.initialize(self)
  local sysinfo = sigarCtx:sysinfo()
  local obj = {name = sysinfo.name, arch = sysinfo.arch,
               version = sysinfo.version, vendor = sysinfo.vendor,
               vendor_version = sysinfo.vendor_version,
               vendor_name = sysinfo.vendor_name or sysinfo.vendor_version}

  table.insert(self._params, obj)
end

--[[ Who is logged In ]]--
local WhoInfo = HostInfo:extend()
function WhoInfo:initialize()
  HostInfo.initialize(self)
  local who = sigarCtx:who()
  local fields = {
    'user',
    'device',
    'time',
    'host'
  }

  for i=1, #who do
    local obj = {}
    for _, v in pairs(fields) do
      obj[v] = who[i][v]
    end
    table.insert(self._params, obj)
  end
end



--[[ Factory ]]--
function create(infoType)
  if infoType == 'CPU' then
    return CPUInfo:new()
  elseif infoType == 'MEMORY' then
    return MemoryInfo:new()
  elseif infoType == 'NETWORK' then
    return NetworkInfo:new()
  elseif infoType == 'DISK' then
    return DiskInfo:new()
  elseif infoType == 'PROCS' then
    return ProcessInfo:new()
  elseif infoType == 'FILESYSTEM' then
    return FilesystemInfo:new()
  elseif infoType == 'SYSTEM' then
    return SystemInfo:new()
  elseif infoType == 'WHO' then
    return WhoInfo:new()
  end

  return NilInfo:new()
end

-- Dump all the info objects to a file
function debugInfo(fileName, callback)
  local data = ''
  for k, v in pairs({'SYSTEM', 'CPU', 'MEMORY', 'NETWORK', 'DISK', 'PROCS', 'FILESYSTEM', 'WHO'}) do
    local info = create(v)
    local obj = info:serialize().metrics
    data = data .. '-- ' .. v .. '.' .. os.type() .. ' --\n\n'
    data = data .. misc.toString(obj)
    data = data .. '\n'
  end
  fs.writeFile(fileName, data, callback)
end

--[[ Exports ]]--
local info = {}
info.CPUInfo = CPUInfo
info.DiskInfo = DiskInfo
info.MemoryInfo = MemoryInfo
info.NetworkInfo = NetworkInfo
info.create = create
info.debugInfo = debugInfo
return info
