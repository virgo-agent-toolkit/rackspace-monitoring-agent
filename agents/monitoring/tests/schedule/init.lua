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

local StateScanner = require('monitoring/lib/schedule').StateScanner

local exports = {}

exports['test_scheduler_scan'] = function(test, asserts)
  local s = StateScanner:new('/data/virgo/agents/monitoring/tests/data/sample.state')
  local count = 0
  s:on('check_needs_run', function(details)
    if count >= 3 then
      test.done()
    end
  end)
  s:scanStates()
end

return exports