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
local fmt = require('string').format
local misc = require('./util/misc')

local Endpoint = Object:extend()

function Endpoint:initialize(host, port)
  if not port then
    ip_and_port = misc.splitAddress(host)
    host = ip_and_port[1]
    port = ip_and_port[2]
  end
  
  self.host = host
  self.port = port
end

function Endpoint.meta.__tostring(table)
  return fmt("%s:%s", table.host, table.port)
end

return {Endpoint=Endpoint}