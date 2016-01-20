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

-- This check returns a list of open connections to remote places

local HostInfo = require('./base').HostInfo
local run = require('virgo/util/misc').run
local Transform = require('stream').Transform
local sigar = require('sigar')
local tableContains = require('virgo/util/misc').tableContains
--- Convenience wrapper around tablecontains
local function includes(value, data)
  return tableContains(function(v) return value==v end, data)
end
--------------------------------------------------------------------------------------------------------------------
local Reader = Transform:extend()
function Reader:initialize()
  Transform.initialize(self, {objectMode = true})
end

local ArpReader = Reader:extend()
function ArpReader:_transform(line, cb)
  -- e.g: '? (162.209.76.3) at 70:ca:9b:8d:8a:bf [ether] on eth0' -> '162.209.76.3'
  self:push(line:match("%((.-)%)"))
  cb()
end


local NetstatReader = Reader:extend()
function NetstatReader:_transform(line, cb)
  local dataTable = {}
  line:gsub("%S+", function(c) table.insert(dataTable, c) end)
  if dataTable[1] ~= 'Active' and dataTable[1] ~= 'Proto' then
    local local_address, local_port = dataTable[4]:match("(.+)%:(.+)")
    local foreign_address, foreign_port = dataTable[5]:match("(.+)%:(.+)")
    self:push({
      local_address = local_address,
      local_port = local_port,
      foreign_address = foreign_address,
      foreign_port = foreign_port,
      state = dataTable[6]
    })
  end
  cb()
end

--------------------------------------------------------------------------------------------------------------------
local Info = HostInfo:extend()

function Info:_run(callback)
  local outTable, errTable = {}, {}
  local connections = {} -- Interim outTable
  local remotes = {} -- Addr of remote hosts we've found
  local ipv4_wildcard_ports = {} -- Ports listening on all addrs
  local ipv6_wildcard_ports = {} -- Same as above but ipv6
  local listeners = {} -- Addr/port combos that are listening
  local active = {} -- All active conns

  local netstatcmd, netstatargs = 'netstat', {'-naten'}
  local arpcmd, arpargs = 'arp', {'-an'}

  -- build a "set" (table keyed by address) of local IP addresses
  local local_ipv4_addresses, local_ipv6_addresses = {}, {}
  local sigarCtx = sigar:new()
  local netifs = sigarCtx:netifs()
  for i=1,#netifs do
    local info = netifs[i]:info()
    if info['address'] then
      table.insert(local_ipv4_addresses, info['address'])
    elseif info['address6'] then
      table.insert(local_ipv6_addresses, info['address6'])
    end
  end

  local function finalCb()
    -- Assign the addresses to a key => address
    table.foreach(connections, function(addr, ports)
      local obj = {}
      obj.address = addr
      if next(ports) then obj.ports = ports end
      table.insert(outTable, obj)
    end)
    self:_pushParams(errTable, outTable)
    return callback()
  end

  local netstatChild = run(netstatcmd, netstatargs)
  local netstatReader = NetstatReader:new()
  netstatChild:pipe(netstatReader)
  netstatReader:on('data', function(data)
    if data.state == 'LISTEN' then
      if data.local_address == '0.0.0.0' then
        table.insert(ipv4_wildcard_ports, data.local_port)
      elseif data.local_address == '::' then
        table.insert(ipv6_wildcard_ports, data.local_port)
      else
        table.insert(listeners, data.local_address..data.local_port)
      end
    elseif includes(data.local_port, ipv4_wildcard_ports) then
      table.insert(remotes, data.foreign_address)
    elseif includes(data.local_port, ipv6_wildcard_ports) then
      table.insert(remotes, data.foreign_address)
    else
      table.insert(remotes, data.foreign_address)
      -- Add foreign remote ip/port
      remotes[data.foreign_address] = data.foreign_port
    end
  end)
  netstatReader:on('error', function(data) table.insert(errTable, data) end)
  netstatReader:once('end', function()

    local arpChild = run(arpcmd, arpargs)
    local arpReader = ArpReader:new()
    arpChild:pipe(arpReader)
    arpReader:on('data', function(data)
      if not includes(data, remotes) then
        active[data] = active[data] or {}
      end
    end)
    arpReader:on('error', function(data) table.insert(errTable, data) end)
    arpReader:once('end', function()
      table.foreach(active, function(address, _)
        local ports = active[address]
        if not next(ports) then
          connections[address] = connections[address] or {}
        else
          table.foreach(ports, function(_, port)
            local tablesToCheck = {ipv4_wildcard_ports, ipv6_wildcard_ports, local_ipv4_addresses, local_ipv6_addresses}
            local found = false
            table.foreach(tablesToCheck, function(_, dataTable)
              if includes(port, dataTable) then found = true end
            end)
            if not found then
              connections[address] = next(connections[address]) and connections[address] or port
            end
          end)
        end
      end)
      finalCb()
    end)
  end)
end

function Info:getPlatforms()
  return {'linux'}
end

function Info:getType()
  return 'CONNECTIONS'
end

exports.Info = Info
exports.ArpReader = ArpReader
exports.NetstatReader = NetstatReader