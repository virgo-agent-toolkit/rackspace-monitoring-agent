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

local env = require('env')

local exports = {}

local testcases = {}

testcases['failed_init'] = {}
testcases['failed_init']['mysql_init'] = function (conn)
  return nil
end

testcases['failed_real_connect'] = {}
testcases['failed_real_connect']['mysql_real_connect'] = function (conn)
  return nil
end
testcases['failed_real_connect']['mysql_errno'] = function (conn)
  return 42
end
testcases['failed_real_connect']['mysql_error'] = function (conn)
  return 'mocked error'
end

testcases['failed_query'] = {}
testcases['failed_query']['mysql_real_connect'] = function (conn)
  return conn
end
testcases['failed_query']['mysql_query'] = function (conn, query)
  return 1
end
testcases['failed_query']['mysql_errno'] = function (conn)
  return 42
end
testcases['failed_query']['mysql_error'] = function (conn)
  return 'mocked error'
end


exports.mock = function(clib)

  local mt = {
    __index = function(t, key)
      local rv = clib[key]
      local tc = env.get('VIRGO_SUBPROC_TESTCASE')
      if tc ~= nil and testcases[tc] ~= nil then
        local tci =  testcases[tc]
        if tci[key] ~= nil then
          return tci[key]
        end
      end

      return clib[key]
     end    
  }

  local rv = {
  }

  setmetatable(rv, mt)

  return rv
end


return exports