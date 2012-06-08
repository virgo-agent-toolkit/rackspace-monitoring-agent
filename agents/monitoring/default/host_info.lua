local Object = require('core').Object
local JSON = require('json')

local fs = require('fs')
local misc = require('./util/misc')
local os = require('os')
local table = require('table')

--[[ HostInfo ]]--
local HostInfo = Object:extend()
function HostInfo:initialize()
  self._s = sigar:new()
  self._params = {}
end

function HostInfo:serialize()
  return {
    metrics = self._params
  }
end

--[[ NilInfo ]]--
local NilInfo = HostInfo:extend()

--[[ CPUInfo ]]--
local CPUInfo = HostInfo:extend()
function CPUInfo:initialize()
  HostInfo.initialize(self)
  local cpus = self._s:cpus()
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
      'cache_size',
      'cores_per_socket',
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
  local disks = self._s:disks()
  local usage_fields = {
    'queue',
    'read_bytes',
    'reads',
    'rtime',
    'service_time',
    'snaptime',
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
  local data = self._s:mem()
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
  if data then
    for k, v in pairs(data_fields) do
      self._params[v] = data[v]
    end
  end
end

--[[ NetworkInfo ]]--
local NetworkInfo = HostInfo:extend()
function NetworkInfo:initialize()
  HostInfo.initialize(self)
  local netifs = self._s:netifs()
  for i=1,#netifs do
    local info = netifs[i]:info()
    local usage = netifs[i]:usage()
    local name = info.name
    local obj = {}

    local info_fields = {
      'address',
      'broadcast',
      'destination',
      'flags',
      'hwaddr',
      'metric',
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
      'rx_frame',
      'tx_packets',
      'tx_bytes',
      'tx_errors',
      'tx_overruns',
      'tx_dropped',
      'tx_collisions',
      'tx_carrier',
      'speed'
    }

    for _, v in pairs(info_fields) do
      obj[v] = info[v]
    end
    for _, v in pairs(usage_fields) do
      obj[v] = usage[v]
    end
    obj['name'] = name
    table.insert(self._params, obj)
  end
end

--[[ Process Info ]]--
local ProcessInfo = HostInfo:extend()
function ProcessInfo:initialize()
  HostInfo.initialize(self)
  local procs = self._s:procs()

  for i=1, #procs do
    local pid = procs[i]
    local proc = self._s:proc(pid)

    local obj = {}
    obj.pid = pid
    obj.exe = {}
    obj.time = {}
    obj.state = {}
    obj.memory = {}

    local t, msg = proc:exe()
    if t then
      local exe_fields = {
        'name',
        'cwd',
        'root'
      }
      for _, v in pairs(exe_fields) do
        obj.exe[v] = t[v]
      end
    else
      obj.exe = 'Unavailable'
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
        obj.time[v] = t[v]
      end
    else
      obj.time = 'Unavailable'
    end

    t, msg = proc:state()
    if t then
      local proc_fields = {
        'name',
        'ppid',
        'tty',
        'priority',
        'nice',
        'processor',
        'threads'
      }
      for _, v in pairs(proc_fields) do
        obj.state[v] = t[v]
      end
    else
      obj.state = 'Unavailable'
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
        obj.memory[v] = t[v]
      end
    else
      obj.memory = 'Unavailable'
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
  end
  return NilInfo:new()
end

-- Dump all the info objects to a file
function debugInfo(fileName, callback)
  local data = ''
  for k, v in pairs({'CPU', 'MEMORY', 'NETWORK', 'DISK', 'PROCS'}) do
    local info = create(v)
    local obj = JSON.parse(info:serialize().jsonPayload)
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
