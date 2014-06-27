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
    char *name;
    unsigned long memory;
    unsigned int cpus;
    unsigned int mhz;
    unsigned int nodes;
    unsigned int sockets;
    unsigned int cores;
    unsigned int threads;
  };

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
    params.details = {}
    params.details.uri = ""
  end
end

function LIBVirtCheck:getType()
  return 'agent.libvirt'
end

function LIBVirtCheck:_gatherDomainInfo(cr, domain)
  local results = {}

  local namePtr = libvirt.virDomainGetName(domainPtr)
  local name = canon(ffi.string(namePtr))
  local domainInfo = ffi.new("virDomainInfo")

  local rv = libvirt.virDomainGetInfo(domainPtr, domainInfo)
  if rv == 0 then
    results.memory = tonumber(domainInfo.memory) * 1024
    results.max_memory = tonumber(domainInfo.maxMem) * 1024
    cr:addMetric(fmt("libvirt.%s.domain.memory", name), nil, 'uint64', results.memory)
    cr:addMetric(fmt("libvirt.%s.domain.max_memory", name), nil, 'uint64', results.max_memory)
  end

  return results
end

function LIBVirtCheck:_runCheckInChild(callback)
  local cr = CheckResult:new(self, {})
  -- local library
  local clib = ffi.load("virt")
  if clib == nil then
    cr:setError("Could not find libvirt")
    callback(cr)
    return
  end
  -- open connection
  local conn = libvirt.virConnectOpenReadOnly("vmwarefusion:///session")
  if conn == nil then
    cr:setError(fmt("Error opening connection (%s)", params.details.uri))
    callback(cr)
    return
  end
  -- how many domains are there?
  local count = libvirt.virConnectNumOfDomains(conn)
  if count <= 0 then
    callback(cr)
    return
  end

  -- gather domain information
  local domids = ffi.new("int[?]", count)
  local ret = libvirt.virConnectListDomains(conn, domids, count)
  if ret < 0 then
    cr:setError("virConnectListDomains Failed")
    callback(cr)
    return
  end

  -- add domain metrics
  local total = 0
  local total_max = 0

  for i=0, ret-1  do
    local domainPtr = libvirt.virDomainLookupByID(conn, domids[i])
    local stats = self._gatherDomainInfo(cr, domainPtr)
    if stats.memory then
      total = total + stats.memory
    end
    if stats.max_memory then
      total_max = total_max + stats.max_memory
    end
  end

  -- add node metrics
  cr:addMetric("libvirt.node.total", nil, 'uint64', total)
  cr:addMetric("libvirt.node.total_max", nil, 'uint64', total_max)

  local nodeInfo = ffi.new("virNodeInfo")
  local rv = libvirt.virNodeGetInfo(conn, nodeInfo)
  if rv == 0 then
    local memory = tonumber(nodeInfo.memory) * 1024
    cr:addMetric("libvirt.node.memory", nil, 'uint64', memory)
  end

  callback(cr)
end

local exports = {}
exports.LIBVirtCheck = LIBVirtCheck
return exports
