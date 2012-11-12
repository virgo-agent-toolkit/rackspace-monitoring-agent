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
local BaseCheck = require('./base').BaseCheck
local CheckResult = require('./base').CheckResult
local Metric = require('./base').Metric
local misc = require('../util/misc')
local constants = require('../util/constants')
local logging = require('logging')
local async = require('async')
local url = require('url')
local http = require('http')
local https = require('https')
local Error = require('core').Error

local fmt = require('string').format

local ApacheCheck = BaseCheck:extend()
function ApacheCheck:initialize(params)
  BaseCheck.initialize(self, 'agent.apache', params)

  self._params = params
  self._url = params.details.url and params.details.url or 'http://127.0.0.1/server-status?auto'
  self._timeout = params.details.timeout and params.details.timeout or constants.DEFAULT_PLUGIN_TIMEOUT

  -- setup default port
  local parsed = url.parse(self._url)
  if not parsed.port then
    if parsed.protocol == 'http' then
      parsed.port = 80
    else
      parsed.port = 443
    end
  end

  self._parsed = parsed
  self._parsed.path = '/server-status?auto'
end

-- "_" Waiting for Connection, "S" Starting up, "R" Reading Request,
-- "W" Sending Reply, "K" Keepalive (read), "D" DNS Lookup,
-- "C" Closing connection, "L" Logging, "G" Gracefully finishing,
-- "I" Idle cleanup of worker, "." Open slot with no current process
function ApacheCheck:_parseScoreboard(board)
  local t = { waiting = 0, starting = 0, reading = 0, sending = 0,
  keepalive = 0, dns = 0, closing = 0, logging = 0,
  gracefully_finishing = 0, idle = 0, open = 0 }

  for c in board:gmatch"." do
    if c == '_' then t.waiting = t.waiting + 1
    elseif c == 'S' then t.starting = t.starting + 1
    elseif c == 'R' then t.reading = t.reading + 1
    elseif c == 'W' then t.sending = t.sending + 1
    elseif c == 'K' then t.keepalive = t.keepalive + 1
    elseif c == 'D' then t.dns = t.dns + 1
    elseif c == 'C' then t.closing = t.closing + 1
    elseif c == 'L' then t.logging = t.logging + 1
    elseif c == 'G' then t.gracefully_finishing = t.gracefully_finishing + 1
    elseif c == 'I' then t.idle = t.idle + 1
    elseif c == '.' then t.open = t.open + 1
    end
  end

  return t
end

function ApacheCheck:_parseLine(line, checkResult)
  local i, j = line:find(":")

  if not i then
    return Error:new('Invalid Apache Status Page')
  end

  local f = line:sub(0, i-1)
  local v = line:sub(i+1, #line)

  f = misc.trim(f:gsub(" ", "_"))
  v = misc.trim(v)

  local metrics = {
    ['Total_Accesses'] = {
      ['type'] = 'gauge'
    },
    ['Total_kBytes'] = {
      ['type'] = 'uint64'
    },
    ['Uptime'] = {
      ['type'] = 'uint64'
    },
    ['BytesPerSec'] = {
      ['type'] = 'uint64'
    },
    ['BytesPerReq'] = {
      ['type'] = 'uint64'
    },
    ['BusyWorkers'] = {
      ['type'] = 'uint64'
    },
    ['IdleWorkers'] = {
      ['type'] = 'uint64'
    },
    ['CPULoad'] = {
      ['type'] = 'double'
    },
    ['ReqPerSec'] = {
      ['type'] = 'double'
    }
  }

  if metrics[f] then
    checkResult:addMetric(f, nil, metrics[f].type, v)
  end

  if f == 'ReqPerSec' then
    checkResult:setStatus(fmt('ReqPerSec: %.2f', v))
  end

  if f == 'Scoreboard' then
    local t = self:_parseScoreboard(v)
    for i,x in pairs(t) do
      checkResult:addMetric(i, nil, 'uint64', x)
    end
  end

  return
end

function ApacheCheck:_parse(data, checkResult)
  for line in data:gmatch("([^\n]*)\n") do
    local err = self:_parseLine(line, checkResult)
    if err then
      checkResult:setError(err.message)
      return
    end
  end
end

function ApacheCheck:run(callback)
  callback = misc.fireOnce(callback)
  local checkResult = CheckResult:new(self, {})
  local protocol = self._parsed.protocol == 'http' and http or https
  local req = protocol.request(self._parsed, function(res)
    local data = ''
    res:on('data', function(_data)
      data = data .. _data
    end)
    res:on('end', function()
      self:_parse(data, checkResult)
      res:destroy()
      callback(checkResult)
    end)
    res:on('error', function(err)
      checkResult:setError(err.message)
      callback(checkResult)
    end)
  end)
  req:on('error', function(err)
    checkResult:setError(err.message)
    callback(checkResult)
  end)
  req:done()
end

local exports = {}
exports.ApacheCheck = ApacheCheck
return exports
