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

local hostinfo = require('/hostinfo')
local fmt = require('string').format
local os = require('os')

local function run(_type)
  return function(test, asserts)
    local hi = hostinfo.create(_type)
    hi:run(function(err, info)
      asserts.ok(not err)
      local data = hi:serialize()
      asserts.ok(type(data.metrics) == 'table')
      test.done()
    end)
  end
end

local exports = {}

exports.test_hostinfo_SYSCTL = function(test, asserts)
  local hi = hostinfo.create(_type)
  hi:run(function(err, info)
    asserts.ok(not err)
    local data = hi:serialize()
    if os.type() == 'Linux' then
      asserts.ok(type(data.metrics) == 'table')
    else
      asserts.ok(type(data.error) == 'string')
    end
    test.done()
  end)
end

for _, v in pairs(hostinfo.classes) do
  local fun_name = fmt('test_hostinfo_%s', v.getType())
  if not exports[fun_name] then
    exports[fun_name] = run(v.getType())
  end
end

return exports
