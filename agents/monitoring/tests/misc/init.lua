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
