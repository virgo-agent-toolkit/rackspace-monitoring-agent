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

local vtime = require('virgo-time')

local times = {
  --   T1          T2          T3           T4     Delta
  {1234567890, 1234567890, 1234567890, 1234567890, 0       },
  {1234567890, 1234567900, 1234567900, 1234567890, 10       },
  {1234567890, 1234567880, 1234567880, 1234567890, -10       },
}

local exports = {}

exports['test_vtime'] = function(test, asserts)
  for k, v in pairs(times) do
    vtime.timesync(v[1], v[2], v[3], v[4])
    asserts.ok(vtime.getDelta() == v[5])
  end
  test.done()
end

return exports
