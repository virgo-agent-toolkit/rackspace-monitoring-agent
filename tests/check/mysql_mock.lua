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
-- Note: we can't make this class scope due to how we are invoking our proxy class...
local RowOffset = 1

function MySQLMock:mysql_init(conn)
  RowOffset = 1
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
function MySQLMock:mysql_num_fields(results)
  return 2
end


local RowResult = {
  {"Aborted_clients", "17"},
  {"Connections", "60"},
  {"Innodb_buffer_pool_pages_dirty", "0"},
  {"Innodb_buffer_pool_pages_flushed", "2"},
  {"Innodb_buffer_pool_pages_free", "8049"},
  {"Innodb_buffer_pool_pages_total", "8191"},
  {"Innodb_row_lock_time", "0"},
  {"Innodb_row_lock_time_avg", "0"},
  {"Innodb_row_lock_time_max", "0"},
  {"Innodb_rows_deleted", "0"},
  {"Innodb_rows_inserted", "0"},
  {"Innodb_rows_read", "0"},
  {"Innodb_rows_updated", "0"},
  {"Qcache_free_blocks", "1"},
  {"Qcache_free_memory", "16759696"},
  {"Qcache_hits", "0"},
  {"Qcache_inserts", "0"},
  {"Qcache_lowmem_prunes", "0"},
  {"Qcache_not_cached", "82"},
  {"Qcache_queries_in_cache", "0"},
  {"Qcache_total_blocks", "1"},
  {"Queries", "590"},
  {"Threads_connected", "1"},
  {"Threads_created", "1"},
  {"Threads_running", "1"},
  {"Uptime", "3212"},
}

function MySQLMock:mysql_fetch_row(results)
  local i = RowOffset
  RowOffset = i + 1
  if RowResult[i] ~= nil then
    local key = RowResult[i][1]
    local val = RowResult[i][2]
    local rv = {}
    rv[0] = ffi.new("char[?]", #key + 1, key)
    rv[1] = ffi.new("char[?]", #val + 1, val)
    return rv
  end
  return nil
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

testcases['fake_results'] = MySQLMock:new()

exports.mock = function(clib)

  -- Handle case where mysqlclient isn't installed at all :(
  if clib == nil then
    clib = {}
  end

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