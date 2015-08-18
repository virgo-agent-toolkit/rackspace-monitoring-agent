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

local HostInfoStdoutSubProc = require('./base').HostInfoStdoutSubProc
local MetricsHandler = require('./base').MetricsHandler
local sigar = require('sigar')

-------------------------------------------------------------------------------

local Handler = MetricsHandler:extend()
function Handler:initialize()
  MetricsHandler.initialize(self)
end

function Handler:_transform(line, callback)
  line = line:gsub("^%s*(.-)%s*$", "%1")
  local _, _, key, value = line:find("(.*)%s(.*)")
  if key then self:push({ name = key, version = value }) end
  callback()
end

-------------------------------------------------------------------------------

local HomeBrewHandler = MetricsHandler:extend()
function HomeBrewHandler:initialize()
  MetricsHandler.initialize(self)
end

function HomeBrewHandler:_transform(line, callback)
  self:push({ name = line, version = 'unknown' })
  callback()
end

-------------------------------------------------------------------------------

local Info = HostInfoStdoutSubProc:extend()
function Info:initialize()
  local command, args
  local sysinfo = sigar:new():sysinfo()
  local vendor = sysinfo.vendor:lower()
  local name = sysinfo.name:lower()
  local handler = Handler:new()
  local commands = {
    ubuntu = { command = 'dpkg-query', args = {'-W'} },
    debian = { command = 'dpkg-query', args = {'-W'} },
    rhel   = { command = 'rpm', args = { '-qa', '--queryformat', '%{NAME}: %{VERSION}-%{RELEASE}\n', } },
    centos = { command = 'rpm', args = { '-qa', '--queryformat', '%{NAME}: %{VERSION}-%{RELEASE}\n', } },
    macosx = { command = 'brew', args = {'leaves'}, handler = HomeBrewHandler:new() },
  }
  if commands[vendor] then
    command = commands[vendor].command
    args = commands[vendor].args
    handler = commands[vendor].handler or handler
  elseif commands[name] then
    command = commands[name].command
    args = commands[name].args
    handler = commands[name].handler or handler
  else
    command = ''
    args = {}
  end
  HostInfoStdoutSubProc.initialize(self, command, args, handler)
end

function Info:getRestrictedPlatforms()
  return {'win32'}
end

function Info:getType()
  return 'PACKAGES'
end

return Info
