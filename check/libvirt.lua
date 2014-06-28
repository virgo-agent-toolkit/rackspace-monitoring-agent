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

local ffi = require('ffi')
local fmt = require('string').format

local SubProcCheck = require('./base').SubProcCheck
local LIBVirtCheck = SubProcCheck:extend()
local CheckResult = require('./base').CheckResult

local function canon(str)
  str = str:gsub("%s+", "_")
  str = str:gsub("^[%W+]", "_")
  str = str:gsub("[:]", "_")
  return str
end

ffi.cdef[[
  typedef enum {
      VIR_CONNECT_LIST_DOMAINS_ACTIVE         = 1 << 0,
      VIR_CONNECT_LIST_DOMAINS_INACTIVE       = 1 << 1,

      VIR_CONNECT_LIST_DOMAINS_PERSISTENT     = 1 << 2,
      VIR_CONNECT_LIST_DOMAINS_TRANSIENT      = 1 << 3,

      VIR_CONNECT_LIST_DOMAINS_RUNNING        = 1 << 4,
      VIR_CONNECT_LIST_DOMAINS_PAUSED         = 1 << 5,
      VIR_CONNECT_LIST_DOMAINS_SHUTOFF        = 1 << 6,
      VIR_CONNECT_LIST_DOMAINS_OTHER          = 1 << 7,

      VIR_CONNECT_LIST_DOMAINS_MANAGEDSAVE    = 1 << 8,
      VIR_CONNECT_LIST_DOMAINS_NO_MANAGEDSAVE = 1 << 9,

      VIR_CONNECT_LIST_DOMAINS_AUTOSTART      = 1 << 10,
      VIR_CONNECT_LIST_DOMAINS_NO_AUTOSTART   = 1 << 11,

      VIR_CONNECT_LIST_DOMAINS_HAS_SNAPSHOT   = 1 << 12,
      VIR_CONNECT_LIST_DOMAINS_NO_SNAPSHOT    = 1 << 13,
  } virConnectListAllDomainsFlags;

  typedef enum {
      VIR_DOMAIN_XML_SECURE       = (1 << 0), /* dump security sensitive information too */
      VIR_DOMAIN_XML_INACTIVE     = (1 << 1), /* dump inactive domain information */
      VIR_DOMAIN_XML_UPDATE_CPU   = (1 << 2), /* update guest CPU requirements according to host CPU */
      VIR_DOMAIN_XML_MIGRATABLE   = (1 << 3), /* dump XML suitable for migration */
  } virDomainXMLFlags;

  typedef struct _virDomainInfo virDomainInfo;
  typedef virDomainInfo *virDomainInfoPtr;

  struct _virDomainInfo {
      unsigned char state;        /* the running state, one of virDomainState */
      unsigned long maxMem;       /* the maximum memory in KBytes allowed */
      unsigned long memory;       /* the memory in KBytes used by the domain */
      unsigned short nrVirtCpu;   /* the number of virtual CPUs for the domain */
      unsigned long long cpuTime; /* the CPU time used in nanoseconds */
  };

  typedef struct _virNodeInfo virNodeInfo;
  typedef virNodeInfo *virNodeInfoPtr;

  struct _virNodeInfo {
    char name[32];
    unsigned long memory;
    unsigned int cpus;
    unsigned int mhz;
    unsigned int nodes;
    unsigned int sockets;
    unsigned int cores;
    unsigned int threads;
  };

  /**
   * virDomainState:
   *
   * A domain may be in different states at a given point in time
   */
  typedef enum {
      VIR_DOMAIN_NOSTATE = 0,     /* no state */
      VIR_DOMAIN_RUNNING = 1,     /* the domain is running */
      VIR_DOMAIN_BLOCKED = 2,     /* the domain is blocked on resource */
      VIR_DOMAIN_PAUSED  = 3,     /* the domain is paused by user */
      VIR_DOMAIN_SHUTDOWN= 4,     /* the domain is being shut down */
      VIR_DOMAIN_SHUTOFF = 5,     /* the domain is shut off */
      VIR_DOMAIN_CRASHED = 6,     /* the domain is crashed */
      VIR_DOMAIN_PMSUSPENDED = 7, /* the domain is suspended by guest
                                     power management */
  } virDomainState;

  typedef void *virConnectPtr;
  typedef void *virDomainPtr;

  void* virConnectOpenReadOnly(const char *name);
  int   virConnectClose(virConnectPtr conn);
  int   virConnectNumOfDomains(virConnectPtr *conn);
  int   virConnectListDomains(virConnectPtr *conn, int *ids, int maxids);
  virDomainPtr virDomainLookupByID(virConnectPtr conn, int id);
  const char *virDomainGetName(virDomainPtr domain);
  char *virDomainGetXMLDesc(virDomainPtr domain, unsigned int flags);
  int   virDomainGetInfo(virDomainPtr domain, virDomainInfoPtr info);
  int   virDomainGetVcpusFlags(virDomainPtr domain, unsigned int flags);
  int   virNodeGetInfo(virConnectPtr conn, virNodeInfoPtr info);

]]

function LIBVirtCheck:initialize(params)
  SubProcCheck.initialize(self, params)

  if params.details == nil then
    self._params.details = {}
    self._params.details.uri = ""
  end
end

function LIBVirtCheck:getType()
  return 'agent.libvirt'
end

function LIBVirtCheck:_stateToString(state)
  local states = {
    [self.clib.VIR_DOMAIN_NOSTATE] = "NOSTATE",
    [self.clib.VIR_DOMAIN_RUNNING] = "RUNNING",
    [self.clib.VIR_DOMAIN_BLOCKED] = "BLOCKED",
    [self.clib.VIR_DOMAIN_PAUSED] = "PAUSED",
    [self.clib.VIR_DOMAIN_SHUTDOWN] = "SHUTDOWN",
    [self.clib.VIR_DOMAIN_SHUTOFF] = "SHUTOFF",
    [self.clib.VIR_DOMAIN_CRASHED] = "CRASHED",
    [self.clib.VIR_DOMAIN_PMSUSPENDED] = "SUSPENDED",
  }
  local name = states[state]
  if name then
    return name
  end
  return "UNKNOWN"
end

function LIBVirtCheck:_gatherDomainInfo(cr, domain, stats)
  local results = {}

  local namePtr = self.clib.virDomainGetName(domain)
  local name = canon(ffi.string(namePtr))
  local info = ffi.new("virDomainInfo")

  local rv = self.clib.virDomainGetInfo(domain, info)
  if rv == 0 then
    results.memory = tonumber(info.memory) * 1024
    results.max_memory = tonumber(info.maxMem) * 1024
    results.cpu_time = tonumber(info.cpuTime)
    results.nr_virt_cpu = tonumber(info.nrVirtCpu)
    results.cpu_time_percentage = 1.0e-7 * results.cpu_time / stats.processors

    cr:addMetric(fmt("libvirt.%s.domain.memory", name), nil, 'uint64', results.memory)
    cr:addMetric(fmt("libvirt.%s.domain.max_memory", name), nil, 'uint64', results.max_memory)
    cr:addMetric(fmt("libvirt.%s.domain.state", name), nil, 'uint64', self:_stateToString(info.state))
    cr:addMetric(fmt("libvirt.%s.domain.cpu_time", name), nil, 'double', results.cpu_time)
    cr:addMetric(fmt("libvirt.%s.domain.nr_virt_cpu", name), nil, 'uint64', results.nr_virt_cpu)
    cr:addMetric(fmt("libvirt.%s.domain.cpu_percentage", name), nil, 'double', results.cpu_time_percentage)
  end

  return results
end

function LIBVirtCheck:_runCheckInChild(callback)
  local cr = CheckResult:new(self, {})

  local libvirtexact = {
    'libvirt'
  }

  local libvirtpaths = {
    '/usr/lib',
    '/usr/local/lib',
    '/usr/lib64',
    '/usr/lib/x86_64-linux-gnu', -- ubuntu, thanks guys.
  }

  local osexts = {
    '',
    '.0'
  }

  -- local library
  self.clib = self:_findLibrary(libvirtexact, libvirtpaths, osexts)
  if self.clib == nil then
    cr:setError("Could not find libvirt")
    callback(cr)
    return
  end

  -- open connection
  local conn = self.clib.virConnectOpenReadOnly(self._params.details.uri)
  if conn == nil then
    cr:setError(fmt("Error opening connection (%s)", self._params.details.uri))
    callback(cr)
    return
  end

  -- how many domains are there?
  local count = self.clib.virConnectNumOfDomains(conn)
  if count < 0 then
    cr:setError("virConnectNumOfDomains errored")
    callback(cr)
    return
  end
  cr:addMetric("libvirt.domains.total", nil, 'uint64', count)

  -- gather domain information
  local domids = ffi.new("int[?]", count)
  local ret = self.clib.virConnectListDomains(conn, domids, count)
  if ret < 0 then
    cr:setError("virConnectListDomains Failed")
    callback(cr)
    return
  end

  -- get node info
  local stats = {}
  stats.processors = 0
  stats.memory = 0
  stats.total = 0
  stats.total_max = 0
  
  local info = ffi.new("virNodeInfo")
  local rv = self.clib.virNodeGetInfo(conn, info)
  if rv == 0 then
    stats.processors = tonumber(info.cpus)
    stats.memory = tonumber(info.memory) * 1024
  end

  cr:addMetric("libvirt.node.memory", nil, 'uint64', stats.memory)
  cr:addMetric("libvirt.node.processors", nil, 'uint64', stats.processors)

  -- add domain metrics
  for i=0, ret-1  do
    local domain = self.clib.virDomainLookupByID(conn, domids[i])
    local dinfo = self:_gatherDomainInfo(cr, domain, stats)
    if dinfo.memory then
      stats.total = stats.total + dinfo.memory
    end
    if dinfo.max_memory then
      stats.total_max = stats.total_max + dinfo.max_memory
    end
  end

  -- add node metrics
  cr:addMetric("libvirt.node.total", nil, 'uint64', total)
  cr:addMetric("libvirt.node.total_max", nil, 'uint64', total_max)

  callback(cr)
end

local exports = {}
exports.LIBVirtCheck = LIBVirtCheck
return exports
