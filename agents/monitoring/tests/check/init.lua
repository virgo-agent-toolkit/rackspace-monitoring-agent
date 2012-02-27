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

local BaseCheck = require('monitoring/lib/check/base').BaseCheck
local CheckResult = require('monitoring/lib/check/base').CheckResult

exports = {}

exports['test_base_check'] = function(test, asserts)
  local check = BaseCheck:new()
  asserts.ok(check._lastResults == nil)
  check:run(function(results)
    asserts.ok(results ~= nil)
    asserts.ok(check._lastResults ~= nil)
    asserts.ok(check._lastResults._nextRun)
    test.done()
  end)
end

return exports