local ffi = require 'ffi'
local uv = require 'uv'
local getaddrinfo = require('./utils').getaddrinfo

local AF_INET = 2
local AF_INET6 = jit.os == "OSX" and 30 or
                 jit.os == "Linux" and 10 or error("Unknown OS")
local SOCK_RAW = 3
local IPPROTO_ICMP = 1
local IPPROTO_ICMP6 = 58
ffi.cdef[[
  int socket(int socket_family, int socket_type, int protocol);
]]

local band = bit.band
local bor = bit.bor
local bnot = bit.bnot
local lshift = bit.lshift
local rshift = bit.rshift
local byte = string.byte
local char = string.char
local sub = string.sub

local e4payload =                 "\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f" ..
  "\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f" ..
  "\x20\x21\x22\x23\x24\x25\x26\x27\x28\x29\x2a\x2b\x2c\x2d\x2e\x2f" ..
  "\x30\x31\x32\x33\x34\x35\x36\x37"
local e6payload =                  "\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f" ..
  "\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f" ..
  "\x20\x21\x22\x23"

-- Calculate 16-bit one's complement of the one's complement sum
local function checksum(buffer)
  local sum = 0
  for i = 1, #buffer, 2 do
    local word = bor(lshift(byte(buffer, i), 8), byte(buffer, i + 1))
    sum = sum + word
    if sum > 0xffff then
      sum = sum - 0xffff -- remove carry bit and add 1
    end
  end

  -- Take complement
  sum = band(bnot(sum), 0xffff)

  -- Return as 2-byte string in network byte order
  return char(rshift(sum, 8), band(sum, 0xff))
end

local waiting = {}
local function processMessage(err, data, address)
  assert(not err, err)
  if not data then
    -- empty event, ignore.
    return
  end
  local first = byte(data, 1)
  if first == 128 then
    -- ICMP6 request, ignore these.
    return
  elseif rshift(first, 4) == 4 then
    -- IPv4 IP header detected, strip it by reading length
    data = sub(data, band(byte(data, 1), 0xf) * 4 + 1)
  end
  local rseq = bor(lshift(byte(data, 7), 8), byte(data, 8))
  local thread = waiting[rseq]
  if thread then
    waiting[rseq] = nil
    return assert(coroutine.resume(thread, sub(data, 9)))
  end
end

local id = math.random(0x10000) % 0x10000
local next_seq = 0

--[[------------------------------- Attributes ---------------------------------
target: String
  hostname or ip address
timeout: Uint32
  timeout in ms
resolver: Optional (IPv4, IPv6) case insensitive
  Determines how to resolve the check target.
--------------------------------- Config Params --------------------------------
count: Optional whole number (1..15)
  Number of pings to send within a single check
------------------------------------- Metrics ----------------------------------
available: Double
  The whole number representing the percent of pings that returned back for a remote.ping check.
average: Double
  The average response time in milliseconds for all ping packets sent out and later retrieved.
count: Int32
  The number of pings (ICMP packets) sent.
maximum: Double
  The maximum roundtrip time in milliseconds of an ICMP packet.
minimum: Double
  The minimum roundtrip time in milliseconds of an ICMP packet.
----------------------------------------------------------------------------]]--
return function (attributes, config, register, set)
  local start = uv.now()
  local delay = config.delay or 2000

  -- Resolve hostname and record time spent
  local family
  local resolver = attributes.resolver and attributes.resolver:lower()
  if resolver == "ipv4" then
    family = "inet"
  elseif resolver == "ipv6" then
    family = "inet6"
  end
  local ip = assert(getaddrinfo(attributes.target, 0, family))
  set("tt_resolve", uv.now() - start)
  set("ip", ip)

  local results = {}

  local payload
  local top, sock, sockfd
  if ip:match("^%d+%.%d+%.%d+%.%d+$") then
    top = "\x08\x00"
    payload = e4payload
    sockfd = ffi.C.socket(AF_INET, SOCK_RAW, IPPROTO_ICMP)
  else
    top = "\x80\x00"
    payload = e6payload
    sockfd = ffi.C.socket(AF_INET6, SOCK_RAW, IPPROTO_ICMP6)
  end
  assert(sockfd >= 0, "Failed to create socket")
  sock = uv.new_udp()
  assert(sock:open(sockfd))

  sock:recv_start(processMessage)
  local timer = uv.new_timer()

  local count = config.count or 5
  for i = 1, count do
    local seq = next_seq
    next_seq = seq + 1
    local begin = uv.now()
    local bottom = char(
      band(rshift(id, 8), 0xff), band(id, 0xff), -- id
      band(rshift(seq, 8), 0xff), band(seq, 0xff), -- seq
      -- Timestamp
      band(rshift(begin, 24), 0xff), band(rshift(begin, 16), 0xff),
      band(rshift(begin, 8), 0xff), band(begin, 0xff)
    ) .. payload
    print("Pinging", ip)
    sock:send(top .. checksum(top .. "\x00\x00" .. bottom) .. bottom, ip, 0)
    local thread = coroutine.running()
    waiting[seq] = thread
    local message
    local delta
    timer:start(delay, 0, function ()
      results[#results + 1] = delta
      assert(coroutine.resume(thread))
    end)
    message = coroutine.yield()
    if message then
      local rbegin = bor(
        lshift(byte(message, 1), 24), lshift(byte(message, 2), 16),
        lshift(byte(message, 3), 8), byte(message, 4))
      assert(rbegin == begin, "echo reply timestamp mistmach")
      assert(message:sub(5) == payload, "echo reply body mismatch")
      delta = uv.now() - begin
      print(delta .. "ms")
      coroutine.yield()
    end
  end
  timer:close()
  sock:close()

  local pass = 0
  local high
  local sum = 0
  local low
  for i = 1, count do
    local ms = results[i]
    if ms then
      pass = pass + 1
      if not high or ms > high then high = ms end
      if not low or ms < low then low = ms end
      sum = sum + ms
    end
  end
  set("duration", uv.now() - start)
  set("available", pass / count)
  set("average", sum / pass)
  set("count", count)
  set("maximum", high)
  set("minimum", low)


end
