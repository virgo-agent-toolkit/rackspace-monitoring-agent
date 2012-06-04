local Object = require('core').Object
local JSON = require('json')

local fs = require('fs')
local misc = require('./util/misc')
local os = require('os')

--[[ Info ]]--
local Info = Object:extend()
function Info:initialize()
  self._s = sigar:new()
  self._params = {}
end

function Info:serialize()
  return {
    jsonPayload = JSON.stringify(self._params)
  }
end

local NilInfo = Info:extend()

--[[ CPUInfo ]]--
local CPUInfo = Info:extend()
function CPUInfo:initialize()
  Info.initialize(self)
  local cpus = self._s:cpus()
  for i=1, #cpus do
    local info = cpus[i]:info()
    local data = cpus[i]:data()
    local bucket = 'cpu.' .. i - 1
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

    self._params[bucket] = {}

    for k, v in pairs(data_fields) do
      self._params[bucket][v] = data[v]
    end
    for k, v in pairs(info_fields) do
      self._params[bucket][v] = info[v]
    end
  end
end

--[[ DiskInfo ]]--
local DiskInfo = Info:extend()
function DiskInfo:initialize()
  Info.initialize(self)
  local disks = self._s:disks()
  local name, usage
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
    name = disks[i]:name()
    usage = disks[i]:usage()
    if name and usage then
      self._params[name] = {}
      for k, v in pairs(usage_fields) do
        self._params[name][v] = usage[v]
      end
    end
  end
end

--[[ MemoryInfo ]]--
local MemoryInfo = Info:extend()
function MemoryInfo:initialize()
  Info.initialize(self)
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
local NetworkInfo = Info:extend()
function NetworkInfo:initialize()
  Info.initialize(self)
  local netifs = self._s:netifs()
  for i=1,#netifs do
    local info = netifs[i]:info()
    local usage = netifs[i]:usage()
    local name = info.name
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

    self._params[name] = {}
    for k, v in pairs(info_fields) do
      self._params[name][v] = info[v]
    end
    for k, v in pairs(usage_fields) do
      self._params[name][v] = usage[v]
    end
  end
end

--[[ Process Info ]]--
local ProcessInfo = Info:extend()
function ProcessInfo:initialize()
  Info.initialize(self)
  local procs = self._s:procs()

  for i=1, #procs do
    local pid = procs[i]
    local proc = self._s:proc(pid)

    self._params[pid] = {}
    self._params[pid].pid = pid
    self._params[pid].exe = {}
    self._params[pid].time = {}
    self._params[pid].state = {}
    self._params[pid].memory = {}

    local t, msg = proc:exe()
    if t then
      local exe_fields = {
        'name',
        'cwd',
        'root'
      }
      for k, v in pairs(exe_fields) do
        self._params[pid].exe[v] = t[v]
      end
    else
      self._params[pid].exe = 'Unavailable'
    end

    t, msg = proc:time()
    if t then
      local time_fields = {
        'start_time',
        'user',
        'sys',
        'total'
      }
      for k, v in pairs(time_fields) do
        self._params[pid].time[v] = t[v]
      end
    else
      self._params[pid].time = 'Unavailable'
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
      for k, v in pairs(proc_fields) do
        self._params[pid].state[v] = t[v]
      end
    else
      self._params[pid].state = 'Unavailable'
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
      for k, v in pairs(memory_fields) do
        self._params[pid].memory[v] = t[v]
      end
    else
      self._params[pid].memory = 'Unavailable'
    end
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

local data = ''
for k, v in pairs({'CPU', 'MEMORY', 'NETWORK', 'DISK', 'PROCS'}) do
  local info = create(v)
  local obj = JSON.parse(info:serialize().jsonPayload)
  data = data .. '-- ' .. v .. '.' .. os.type() .. ' --\n\n'
  data = data .. misc.toString(obj)
  data = data .. '\n'
end
fs.writeFile('os.txt', data, function() p('wrote file') end)

--[[ Exports ]]--
local info = {}
info.CPUInfo = CPUInfo
info.DiskInfo = DiskInfo
info.MemoryInfo = MemoryInfo
info.NetworkInfo = NetworkInfo
info.create = create
return info
