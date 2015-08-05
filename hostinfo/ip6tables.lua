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

-------------------------------------------------------------------------------

local Handler = MetricsHandler:extend()
function Handler:initialize()
  MetricsHandler.initialize(self)
end

function Handler:_transform(line, callback)
  local iter = line:gmatch("%S+")
  local type = iter()
  if type == '-P' then
    self:push({type = type, chain = iter(), policy = iter()})
  elseif type == '-N' then
    self:push({type = type, chain = iter()})
  elseif type == '-A' then
    local policy = ''
    local chain = iter()
    local idx = line:find(chain)
    if idx then policy = line:sub(idx) end
    self:push({type = type, chain = chain, policy = policy})
  end
  callback()
end

-------------------------------------------------------------------------------

local Info = HostInfoStdoutSubProc:extend()
function Info:initialize()
  HostInfoStdoutSubProc.initialize(self,
                                   'ip6tables', {'-S'},
                                   Handler:new())
end

function Info:getRestrictedPlatforms()
  return {'win32', 'darwin'}
end

function Info:getType()
  return 'IP6TABLES'
end

return Info
