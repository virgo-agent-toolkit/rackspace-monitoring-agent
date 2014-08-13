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
  return {}
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
function MySQLMock:mysql_fetch_fields(result)
   return {[0]={name = 'Master_Host'},
           [1]={name = 'Slave_IO_State'},
   }
end

local ColumnRowResult = {[1]={[0]='localhost',[1]='3'}}

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

local MockQueryData = MySQLMock:extend()

local MysqlResult = Object:extend()
function MysqlResult:initialize(rows, kvquery)
  self.rows = rows
  self.kvquery = kvquery
  self.rowIndex = 1
end

function MysqlResult:count()
  return #self.rows
end

function MysqlResult:fetchColumnRow()
  local rv = {}
  local row = ColumnRowResult[self.rowIndex]
  if not row then
    return nil
  end
  rv[0] = ffi.new("char[?]", #row[0], row[0])
  rv[1] = ffi.new("char[?]", #row[1], row[1])

  self.rowIndex = self.rowIndex + 1
  return rv
end


function MysqlResult:fetchRow()
  local rv = {}

  local row = self.rows[self.rowIndex]

  if not row then
    return nil
  end

  local key = row[1]
  local value = row[2]

  rv[0] = ffi.new("char[?]", #key + 1, key)
  rv[1] = ffi.new("char[?]", #value + 1, value)

  self.rowIndex = self.rowIndex + 1

  return rv
end

local QUERIES = {
  ['show slave status'] = {
    {'Master_Host', 'localhost'},
    {'Slave_IO_State', '3'},
    {'Last_IO_State', 'error'},
  },
  ['show global status'] = {
    {'Uptime', '2'},
  },
  ['show global variables'] = {
    {'query_cache_size', '1'},
  },
}

local HANDLES = {}
local HANDLE_ID = 1

function registerHandle(ctx)
  HANDLES[ctx.id] = ctx
end

function MockQueryData.mysql_init()
  local ctx = {}
  ctx.id = HANDLE_ID
  registerHandle(ctx)
  HANDLE_ID = HANDLE_ID + 1
  return ctx
end

function MockQueryData.mysql_query(conn, query)
  local kvquery = true
  if query == 'show slave status' then
    kvquery = false
  end
  conn.results = MysqlResult:new(QUERIES[query], kvquery)
  return 0
end

function MockQueryData.mysql_use_result(conn)
  return conn.results
end

-- Need to mock out a new fetch row based on this query
-- or maybe just mod the one above to conditionally return?
function MockQueryData.mysql_fetch_row(results)
  if results.kvquery then
    return results:fetchRow()
  else
    return results:fetchColumnRow()
  end
end

testcases['test_multi_query'] = MockQueryData:new()

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

  local rv = {}
  setmetatable(rv, mt)
  return rv
end


return exports
