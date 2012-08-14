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

local logging = require('logging')
local Error = require('core').Error

local delta = 0
local delay = 0

local function now()
  return virgo.gmtnow() + delta
end

local function raw()
  return virgo.gmtnow()
end

local function setDelta(_delta)
  delta = _delta
end

--[[

This algorithm follows the NTP algorithm found here:

http://www.eecis.udel.edu/~mills/ntp/html/warp.html

T1 = agent departure timestamp
T2 = server receieved timestamp
T3 = server transmit timestamp
T4 = agent destination timestamp

]]--
local function timesync(T1, T2, T3, T4)
  if not T1 or not T2 or not T3 or not T4 then
    return Error:new('T1, T2, T3, or T4 was null. Failed to sync time.')
  end

  logging.debug('T1 = %i', T1)
  logging.debug('T2 = %i', T2)
  logging.debug('T3 = %i', T3)
  logging.debug('T4 = %i', T4)

  delta = ((T2 - T1) + (T3 - T4)) / 2
  delay = ((T4 - T1) + (T3 - T2))

  logging.infof('Setting time delta to %i', delta)

  return
end

local exports = {}
exports.setDelta = setDelta
exports.now = now
exports.raw = raw
exports.timesync = timesync
return exports
