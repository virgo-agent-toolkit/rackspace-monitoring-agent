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

local Object = require('core').Object
local vutils = require('virgo_utils')

--[[ HostInfo ]]--
local HostInfo = Object:extend()
function HostInfo:initialize()
  self._params = {}
end

function HostInfo:serialize()
  return {
    metrics = self._params,
    timestamp = vutils.gmtNow()
  }
end

function HostInfo:run(callback)
  callback(nil, self._params)
end

local exports = {}
exports.HostInfo = HostInfo
return exports
