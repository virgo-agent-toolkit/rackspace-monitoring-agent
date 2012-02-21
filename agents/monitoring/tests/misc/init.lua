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

exports = {}
no = {}

local sigar = require("sigar")
local Uuid = require('monitoring/lib/util/uuid')

exports['test_uuid_generation'] = function(test, asserts)
  local s = sigar:new()
  local netifs = s:netifs()
  local hwaddrStr = netifs[2]:info().hwaddr
  local uuid1,uuid2 = Uuid:new(hwaddrStr),Uuid:new(hwaddrStr)
  -- string reps should be different.
  asserts.ok(uuid1:toString() ~= uuid2:toString())
  -- last chunk should be the same.
  asserts.equals(uuid1:toString():reverse():sub(1, 10), uuid2:toString():reverse():sub(1, 10))
  test.done()
end

return exports
