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

local fmt = require('string').format

local SubProcCheck = require('./base').SubProcCheck
local MySQLCheck = SubProcCheck:extend()
local CheckResult = require('./base').CheckResult


function MySQLCheck:initialize(params)
  SubProcCheck.initialize(self, 'agent.mysql', params)

  if params.details == nil then
    params.details = {}
  end

  self.mysql_password = params.details.password and params.details.password or nil
  self.mysql_username = params.details.username and params.details.username or nil
  self.mysql_host = params.details.host and params.details.host or '127.0.0.1'
  self.mysql_port = params.details.port and tonumber(params.details.port) or 3306

end

local loadedCDEF = false
local function loadMySQL()
  local ffi = require('ffi')

  if loadedCDEF == true then
    return
  end

  loadedCDEF = true

  ffi.cdef[[
  typedef void MYSQL;
  typedef void MYSQL_RES;
  typedef char **MYSQL_ROW;

  enum mysql_option
  {
    MYSQL_OPT_CONNECT_TIMEOUT, MYSQL_OPT_COMPRESS, MYSQL_OPT_NAMED_PIPE,
    MYSQL_INIT_COMMAND, MYSQL_READ_DEFAULT_FILE, MYSQL_READ_DEFAULT_GROUP,
    MYSQL_SET_CHARSET_DIR, MYSQL_SET_CHARSET_NAME, MYSQL_OPT_LOCAL_INFILE,
    MYSQL_OPT_PROTOCOL, MYSQL_SHARED_MEMORY_BASE_NAME, MYSQL_OPT_READ_TIMEOUT,
    MYSQL_OPT_WRITE_TIMEOUT, MYSQL_OPT_USE_RESULT,
    MYSQL_OPT_USE_REMOTE_CONNECTION, MYSQL_OPT_USE_EMBEDDED_CONNECTION,
    MYSQL_OPT_GUESS_CONNECTION, MYSQL_SET_CLIENT_IP, MYSQL_SECURE_AUTH,
    MYSQL_REPORT_DATA_TRUNCATION, MYSQL_OPT_RECONNECT,
    MYSQL_OPT_SSL_VERIFY_SERVER_CERT, MYSQL_PLUGIN_DIR, MYSQL_DEFAULT_AUTH
  };

  MYSQL* mysql_init(MYSQL *mysql);

  MYSQL* mysql_real_connect(MYSQL *mysql,
                            const char *host,
                            const char *user,
                            const char *passwd,
                            const char *db,
                            unsigned int port,
                            const char *unix_socket,
                            unsigned long clientflag);

  unsigned int mysql_errno(MYSQL *mysql);
  const char* mysql_error(MYSQL *mysql);

  int mysql_options(MYSQL *mysql, enum mysql_option option, const void *arg);

  int mysql_query(MYSQL *mysql, const char *q);

  MYSQL_RES* mysql_use_result(MYSQL *mysql);
  void mysql_free_result(MYSQL_RES *result);

  unsigned int mysql_num_fields(MYSQL_RES *res);
  MYSQL_ROW mysql_fetch_row(MYSQL_RES *result);

  void mysql_close(MYSQL *sock);

  void mysql_server_end(void);

  ]]

end

-- List of MySQL Stats that we export, along with their metric type.
local stat_map = {
  Aborted_clients = { type = 'uint64', alias = 'core.aborted_clients', unit = 'clients' },
  Connections = { type = 'gauge', alias = 'core.connections', unit = 'connections'},

  Innodb_buffer_pool_pages_dirty = { type = 'uint64', alias = 'innodb.buffer_pool_pages_dirty', unit = 'pages' },
  Innodb_buffer_pool_pages_free = { type = 'uint64', alias = 'innodb.buffer_pool_pages_free', unit = 'pages'},
  Innodb_buffer_pool_pages_flushed = { type = 'uint64', alias = 'innodb.buffer_pool_pages_flushed', unit = 'pages'},
  Innodb_buffer_pool_pages_total = { type = 'uint64', alias = 'innodb.buffer_pool_pages_total', unit = 'pages'},
  Innodb_row_lock_time = { type = 'uint64', alias = 'innodb.row_lock_time', unit = 'milliseconds'},
  Innodb_row_lock_time_avg = { type = 'uint64', alias = 'innodb.row_lock_time_avg', unit = 'milliseconds'},
  Innodb_row_lock_time_max = { type = 'uint64', alias = 'innodb.row_lock_time_max', unit = 'milliseconds'},
  Innodb_rows_deleted = { type = 'gauge', alias = 'innodb.rows_deleted', unit = 'rows'},
  Innodb_rows_inserted = { type = 'gauge', alias = 'innodb.rows_inserted', unit = 'rows'},
  Innodb_rows_read = { type = 'gauge', alias = 'innodb.rows_read', unit = 'rows'},
  Innodb_rows_updated = { type = 'gauge', alias = 'innodb.rows_updated', unit = 'rows'},

  Queries = { type = 'gauge', alias = 'core.queries', unit = 'queries'},

  Threads_connected = { type = 'uint64', alias = 'threads.connected', unit = 'threads'},
  Threads_created = { type = 'uint64', alias = 'threads.created', unit = 'threads'},
  Threads_running = { type = 'uint64', alias = 'threads.running', unit = 'threads'},

  Uptime = { type = 'uint64', alias = 'core.uptime', unit = 'seconds'},

  Qcache_free_blocks = { type = 'uint64', alias = 'qcache.free_blocks', unit = 'blocks'},
  Qcache_free_memory = { type = 'uint64', alias = 'qcache.free_memory', unit = 'bytes'},
  Qcache_hits = { type = 'gauge', alias = 'qcache.hits', unit = 'hits'},
  Qcache_inserts  = { type = 'gauge', alias = 'qcache.inserts', unit = 'inserts'},
  Qcache_lowmem_prunes  = { type = 'gauge', alias = 'qcache.lowmem_prunes', unit = 'prunes'},
  Qcache_not_cached = { type = 'gauge', alias = 'qcache.not_cached', unit = 'queries'},
  Qcache_queries_in_cache = { type = 'uint64', alias = 'qcache.queries_in_cache', unit = 'queries'},
  Qcache_total_blocks = { type = 'uint64', alias = 'qcache.total_blocks', unit = 'blocks'},
}

function MySQLCheck:_runCheckInChild(callback)
  local ffi = require('ffi')
  local cr = CheckResult:new(self, {})

  local mysqlexact = {
    'libmysqlclient_r',
    'libmysqlclient',
  }

  local mysqlpattern = {
    'libmysqlclient_r%.so.*',
    'libmysqlclient_r%.dylib.*',
    'libmysqlclient_r%.dll.*',
    'libmysqlclient%.so.*',
    'libmysqlclient%.dylib.*',
    'libmysqlclient%.dll.*',
  }

  local mysqlpaths = {
    '/usr/lib',
    '/usr/local/lib',
    '/usr/local/mysql/lib',
    '/opt/local/lib',
  }

  local clib = self:_findLibrary(mysqlexact, mysqlpattern, mysqlpaths)
  if clib == nil then
    cr:setError("Couldn't find libmysqlclient_r")
    callback(cr)
    return
  end

  loadMySQL()

  local conn = clib.mysql_init(nil)

  if conn == nil then
    cr:setError('mysql_init failed')
    callback(cr)
    return
  end

  -- http://dev.mysql.com/doc/refman/5.0/en/mysql-real-connect.html
  local rv = clib.mysql_real_connect(conn,
                                     self.mysql_host,
                                     self.mysql_username,
                                     self.mysql_password,
                                     nil,
                                     self.mysql_port,
                                     nil,
                                     0)

  if rv == nil then
    local host = self.mysql_host and self.mysql_host or '(null)'
    local port = self.mysql_port and self.mysql_port or 0
    local username = self.mysql_username and self.mysql_username or '(null)'

    cr:setError(fmt('mysql_real_connect(host=%s, port=%d, username=%s) failed: (%d) %s',
                    host,
                    port,
                    username,
                    clib.mysql_errno(conn),
                    ffi.string(clib.mysql_error(conn))))
    clib.mysql_close(conn)
    callback(cr)
    return
  end

  rv = clib.mysql_query(conn, "show status")
  if rv ~= 0 then
    cr:setError(fmt('mysql_query "show status" failed: (%d) %s',
                    clib.mysql_errno(conn),
                    ffi.string(clib.mysql_error(conn))))
    clib.mysql_close(conn)
    callback(cr)
    return
  end

  local result = clib.mysql_use_result(conn)
  if result == nil then
    cr:setError(fmt('mysql_use_result failed: (%d) %s',
                    clib.mysql_errno(conn),
                    ffi.string(clib.mysql_error(conn))))
    clib.mysql_close(conn)
    callback(cr)
    return
  end

  local nfields = clib.mysql_num_fields(result)
  if nfields ~= 2 then
    cr:setError(fmt('mysql_num_fields failed: expected 2 fields, but got %i',
                    nfields))
    clib.mysql_free_result(result)
    clib.mysql_close(conn)
    callback(cr)
    return
  end

  while true do
    r = clib.mysql_fetch_row(result)
    if r == nil then
      break
    end
    local keyname = ffi.string(r[0])
    local kstat = stat_map[keyname]
    if kstat ~= nil then
      -- TODO: would be nice to use mysql native types here?
      local val = ffi.string(r[1])
      cr:addMetric(kstat.alias, nil, kstat.type, val, rawget(kstat, 'unit'))
    end
  end

  -- TOOD: status message
  callback(cr)
  return
end

local exports = {}
exports.MySQLCheck = MySQLCheck
return exports
