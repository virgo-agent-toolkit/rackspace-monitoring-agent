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
local ffi = require('ffi')
local Object = require('core').Object

local exports = {}

local testcases = {}

local MySQLMock = Object:extend()

function MySQLMock:mysql_init(conn)
  return 1
end
function MySQLMock:mysql_close(conn)
  return
end
function MySQLMock:mysql_real_connect(conn)
  return conn
end

function MySQLMock:mysql_errno(conn)
  return 42
end

function MySQLMock:mysql_error(conn)
  return 'mocked error'
end

function MySQLMock:mysql_query(conn, query)
  return 0
end
function MySQLMock:mysql_use_result(conn)
  return {}
end
function MySQLMock:mysql_free_result(result)
  return
end



local MockInit = MySQLMock:extend()
function MockInit:mysql_init(conn)
  return nil
end
testcases['failed_init'] = MockInit:new()


local MockRealConnect = MySQLMock:extend()
function MockRealConnect:mysql_real_connect(conn)
  return nil
end
testcases['failed_real_connect'] = MockRealConnect:new()


local MockQuery = MySQLMock:extend()
function MockQuery:mysql_query(conn, query)
  return 1
end
testcases['failed_query'] = MockQuery:new()

local MockUseResult = MySQLMock:extend()
function MockUseResult:mysql_use_result(conn)
  return nil
end
testcases['failed_use_result'] = MockUseResult:new()

local MockNumFields = MySQLMock:extend()
function MockNumFields:mysql_num_fields(results)
  return 3
end
testcases['failed_num_fields'] = MockNumFields:new()

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