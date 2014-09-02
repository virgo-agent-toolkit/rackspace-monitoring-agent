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

local ffi = require('ffi')

local fmt = require('string').format

local SubProcCheck = require('./base').SubProcCheck
local MySQLCheck = SubProcCheck:extend()
local CheckResult = require('./base').CheckResult


function MySQLCheck:initialize(params)
  SubProcCheck.initialize(self, params)

  if params.details == nil then
    params.details = {}
  end

  self.mysql_password = params.details.password and params.details.password or nil
  self.mysql_username = params.details.username and params.details.username or nil
  self.mysql_host = params.details.host and params.details.host or '127.0.0.1'
  self.mysql_port = params.details.port and tonumber(params.details.port) or 3306
  self.mysql_socket = params.details.socket and params.details.socket or nil
  self.mysql_mycnf = params.details.mycnf and params.details.mycnf or nil
end

function MySQLCheck:getType()
  return 'agent.mysql'
end

local loadedCDEF = false
local function loadMySQL()

  if loadedCDEF == true then
    return
  end

  loadedCDEF = true

  ffi.cdef[[
  typedef void MYSQL;
  typedef void MYSQL_RES;
  typedef char **MYSQL_ROW;

  enum enum_field_types { MYSQL_TYPE_DECIMAL, MYSQL_TYPE_TINY,
                          MYSQL_TYPE_SHORT,  MYSQL_TYPE_LONG,
                          MYSQL_TYPE_FLOAT,  MYSQL_TYPE_DOUBLE,
                          MYSQL_TYPE_NULL,   MYSQL_TYPE_TIMESTAMP,
                          MYSQL_TYPE_LONGLONG,MYSQL_TYPE_INT24,
                          MYSQL_TYPE_DATE,   MYSQL_TYPE_TIME,
                          MYSQL_TYPE_DATETIME, MYSQL_TYPE_YEAR,
                          MYSQL_TYPE_NEWDATE, MYSQL_TYPE_VARCHAR,
                          MYSQL_TYPE_BIT,
                          MYSQL_TYPE_NEWDECIMAL=246,
                          MYSQL_TYPE_ENUM=247,
                          MYSQL_TYPE_SET=248,
                          MYSQL_TYPE_TINY_BLOB=249,
                          MYSQL_TYPE_MEDIUM_BLOB=250,
                          MYSQL_TYPE_LONG_BLOB=251,
                          MYSQL_TYPE_BLOB=252,
                          MYSQL_TYPE_VAR_STRING=253,
                          MYSQL_TYPE_STRING=254,
                          MYSQL_TYPE_GEOMETRY=255
  };

  typedef struct st_mysql_field {
    char *name;
    char *org_name;
    char *table;
    char *org_table;
    char *db;
    char *catalog;
    char *def;
    unsigned long length;
    unsigned long max_length;
    unsigned int name_length;
    unsigned int org_name_length;
    unsigned int table_length;
    unsigned int org_table_length;
    unsigned int db_length;
    unsigned int catalog_length;
    unsigned int def_length;
    unsigned int flags;
    unsigned int decimals;
    unsigned int charsetnr;
    enum enum_field_types type;
    void *extension;
  } MYSQL_FIELD;

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
  MYSQL_FIELD* mysql_fetch_fields(MYSQL_RES *result);

  void mysql_close(MYSQL *sock);

  void mysql_server_end(void);

  ]]
end

-- List of MySQL Stats that we export, along with their metric type.
local status_stat_map = {
  -- show status mappings
  Aborted_clients = { type = 'uint64', alias = 'core.aborted_clients', unit = 'clients' },
  Connections = { type = 'gauge', alias = 'core.connections', unit = 'connections'},

  Innodb_buffer_pool_pages_dirty = { type = 'uint64', alias = 'innodb.buffer_pool_pages_dirty', unit = 'pages' },
  Innodb_buffer_pool_pages_free = { type = 'uint64', alias = 'innodb.buffer_pool_pages_free', unit = 'pages'},
  Innodb_buffer_pool_pages_flushed = { type = 'uint64', alias = 'innodb.buffer_pool_pages_flushed', unit = 'pages'},
  Innodb_buffer_pool_pages_total = { type = 'uint64', alias = 'innodb.buffer_pool_pages_total', unit = 'pages'},
  Innodb_row_lock_time = { type = 'gauge', alias = 'innodb.row_lock_time', unit = 'milliseconds'},
  Innodb_row_lock_time_avg = { type = 'uint64', alias = 'innodb.row_lock_time_avg', unit = 'milliseconds'},
  Innodb_row_lock_time_max = { type = 'uint64', alias = 'innodb.row_lock_time_max', unit = 'milliseconds'},
  Innodb_rows_deleted = { type = 'gauge', alias = 'innodb.rows_deleted', unit = 'rows'},
  Innodb_rows_inserted = { type = 'gauge', alias = 'innodb.rows_inserted', unit = 'rows'},
  Innodb_rows_read = { type = 'gauge', alias = 'innodb.rows_read', unit = 'rows'},
  Innodb_rows_updated = { type = 'gauge', alias = 'innodb.rows_updated', unit = 'rows'},
  Innodb_buffer_pool_pages_data = { type = 'uint64', alias = 'innodb.buffer_pool_pages_data', unit = 'pages'},
  Innodb_buffer_pool_pages_dirty = { type = 'uint64', alias = 'innodb.buffer_pool_pages_dirty', unit = 'pages'},
  Innodb_buffer_pool_pages_free = { type = 'uint64', alias = 'innodb.buffer_pool_pages_free', unit = 'pages'},
  Innodb_buffer_pool_pages_total = { type = 'uint64', alias = 'innodb.buffer_pool_pages_total', unit = 'pages'},
  Innodb_buffer_pool_read_requests = { type = 'gauge', alias = 'innodb.buffer_pool_read_requests', unit = 'queries'},
  Innodb_buffer_pool_reads = { type = 'gauge', alias = 'innodb.buffer_pool_reads', unit = 'queries'},
  Innodb_data_pending_fsyncs = { type = 'uint64', alias = 'innodb.data_pending_fsyncs', unit = 'queries'},
  Innodb_data_pending_reads = { type = 'uint64', alias = 'innodb.data_pending_reads', unit = 'queries'},
  Innodb_data_pending_writes = { type = 'uint64', alias = 'innodb.data_pending_writes', unit = 'queries'},
  Innodb_os_log_pending_fsyncs = { type = 'uint64', alias = 'innodb.os_log_pending_fsyncs', unit = 'queries'},
  Innodb_os_log_pending_writes = { type = 'uint64', alias = 'innodb.os_log_pending_writes', unit = 'queries'},
  Innodb_pages_created = { type = 'gauge', alias = 'innodb.pages_created', unit = 'pages'},
  Innodb_pages_read = { type = 'gauge', alias = 'innodb.pages_read', unit = 'pages'},
  Innodb_pages_written = { type = 'gauge', alias = 'innodb.pages_written', unit = 'pages'},
  Innodb_row_lock_waits = { type = 'gauge', alias = 'innodb.row_lock_waits', unit = 'locks'},
  Innodb_buffer_pool_pages_flushed = { type = 'gauge', alias = 'innodb.buffer_pool_pages_flushed', unit = 'pages'},

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

  Bytes_received = { type = 'gauge', alias = 'bytes.received', unit = 'bytes'},
  Bytes_sent = { type = 'gauge', alias = 'bytes.sent', unit = 'bytes'},

  Handler_delete = { type = 'gauge', alias = 'handler.delete', unit = 'queries'},
  Handler_read_first = { type = 'gauge', alias = 'handler.read_first', unit = 'queries'},
  Handler_read_key = { type = 'gauge', alias = 'handler.read_key', unit = 'queries'},
  Handler_read_next = { type = 'gauge', alias = 'handler.read_next', unit = 'queries'},
  Handler_read_prev = { type = 'gauge', alias = 'handler.read_prev', unit = 'queries'},
  Handler_read_rnd = { type = 'gauge', alias = 'handler.read_rnd', unit = 'queries'},
  Handler_read_rnd_next = { type = 'gauge', alias = 'handler.read_rnd_next', unit = 'queries'},
  Handler_rollback = { type = 'uint64', alias = 'handler.rollback', unit = 'queries'},
  Handler_savepoint = { type = 'uint64', alias = 'handler.savepoint', unit = 'queries'},
  Handler_savepoint_rollback = { type = 'uint64', alias = 'handler.savepoint_rollback', unit = 'queries'},
  Handler_update = { type = 'gauge', alias = 'handler.update', unit = 'queries'},
  Handler_write = { type = 'gauge', alias = 'handler.write', unit = 'queries'},
  Handler_commit = { type = 'gauge', alias = 'handler.commit', unit = 'queries'},

  Slave_running = { type = 'string', alias = 'replication.slave_running', unit = ''},
}

local variables_stat_map = {
  -- show variables mappings
  query_cache_size = { type = 'uint64', alias = 'qcache.size', unit = 'bytes'},
  max_connections = { type = 'uint64', alias = 'max.connections', unit = 'connections'},
  innodb_buffer_pool_size = { type = 'uint64', alias = 'innodb.buffer_pool_size', unit = 'bytes'},
  key_buffer_size = { type = 'uint64', alias = 'key.buffer_size', unit = 'bytes'},
  thread_cache_size = { type = 'uint64', alias = 'thread.cache_size', unit = 'bytes'},
}

local replication_stat_map = {
  -- show slave status mappings
  Read_Master_Log_Pos = { type = 'uint64', alias = 'replication.read_master_log_pos', unit = 'position'},
  Slave_IO_Running = { type = 'string', alias = 'replication.slave_io_running', unit = ''},
  Slave_SQL_Running = { type = 'string', alias = 'replication.slave_sql_running', unit = ''},
  Exec_Master_Log_Pos = { type = 'uint64', alias = 'replication.exec_master_log_pos', unit = 'position'},
  Relay_Log_Pos = { type = 'uint64', alias = 'replication.relay_log_pos', unit = 'position'},
  Relay_Log_Size = { type = 'uint64', alias = 'replication.relay_log_size', unit = 'bytes'},
  Seconds_Behind_Master = { type = 'uint64', alias = 'replication.seconds_behind_master', unit = 'seconds'},
  Last_Errno = { type = 'uint64', alias = 'replication.last_errno', unit = 'errno'},
  Slave_IO_State = { type = 'string', alias = 'replication.slave_io_state', unit = ''},
  Last_IO_Error = { type = 'string', alias = 'replication.last_io_error', unit = ''},
  Slave_open_temp_tables = { type = 'uint64', alias = 'replication.slave_open_temp_tables', unit = 'tables'},
  Slave_retried_transactions = { type = 'uint64', alias = 'replication.slave_retried_transactions', unit = 'transactions'},
}


local function runQuery(conn, query, cr, clib)
  rv = clib.mysql_query(conn, query)
  if rv ~= 0 then
    cr:setError(fmt('mysql_query "%s" failed: (%d) %s',
                    query,
                    clib.mysql_errno(conn),
                    ffi.string(clib.mysql_error(conn))))
    clib.mysql_close(conn)
    return
  end

  local result = clib.mysql_use_result(conn)
  if result == nil then
    cr:setError(fmt('mysql_use_result failed: (%d) %s',
                    clib.mysql_errno(conn),
                    ffi.string(clib.mysql_error(conn))))
    clib.mysql_close(conn)
    return
  end
  return result
end

local function runKeyValueQuery(conn, query, cr, clib, stat_map)
  local result = runQuery(conn, query, cr, clib)
  local nfields = clib.mysql_num_fields(result)

  -- Key/Value assumes 2 fields only. examples of this
  -- are the show XXX syntax that return Variable_Name/Value
  -- combinations.
  if nfields ~= 2 then
    cr:setError(fmt('mysql_num_fields failed: expected 2 fields, but got %i',
                    nfields))
    clib.mysql_free_result(result)
    clib.mysql_close(conn)
    return
  end

  while true do
    local r = clib.mysql_fetch_row(result)
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
end

local function runColumnBasedQuery(conn, query, cr, clib, stat_map)
  local result = runQuery(conn, query, cr, clib)
  local nfields = clib.mysql_num_fields(result)
  local colnames = clib.mysql_fetch_fields(result)
  local fieldnames = {}

  for i=0,nfields-1 do
    fieldnames[i] = ffi.string(colnames[i].name)
  end

  -- note, these will clobber any multi row values because the name
  -- of the metric is the same for each row. It is the name of the
  -- column header. This may be expanded in the future to allow a
  -- prepended special column to each metric key. An example would be
  -- a 'name' column, which would produce unique values for queries
  -- such as show processlist.
  while true do
    local r = clib.mysql_fetch_row(result)
    if r == nil then
      break
    end

    -- This will use the columns as the stat_map keys, and assumes the
    -- order is the same between the field names and row values, which
    -- is valid as per the mysql c lib. It will only add metrics that
    -- are niether empty nor nil.
    for i=0,nfields-1 do
       kstat = stat_map[fieldnames[i]]
       if kstat ~= nil and r[i] ~= nil then
         local val = ffi.string(r[i])
         if val ~= '' then
            cr:addMetric(kstat.alias, nil, kstat.type, val, rawget(kstat, 'unit'))
         end
       end
    end
  end
end

function MySQLCheck:getQueries()
   return {
     replication_query = {
       query = 'show slave status',
       stat_map = replication_stat_map,
       kvquery = false
     },
     status_query = {
       query = "show global status",
       stat_map = status_stat_map,
       kvquery = true
     },
     variables_query = {
       query = 'show global variables',
       stat_map = variables_stat_map,
       kvquery = true
     },
   }
end

function MySQLCheck:_runCheckInChild(callback)
  local cr = CheckResult:new(self, {})

  local mysqlexact = {
    'libmysqlclient_r',
    'libmysqlclient'
  }

  local mysqlpaths = {
    '/usr/lib',
    '/usr/lib/mysql',
    '/usr/local/lib',
    '/usr/local/mysql/lib',
    '/opt/local/lib',
    '/usr/lib64',
    '/usr/lib64/mysql', -- RHEL5, thanks guys.
    '/usr/lib/x86_64-linux-gnu', -- ubuntu, thanks guys.
  }

  local osexts = {
    '', -- default to no os extension
    '.16',
    '.17',
    '.18'
  }

  local clib = self:_findLibrary(mysqlexact, mysqlpaths, osexts)
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

  -- read mycnf
  local rv
  if self.mysql_mycnf then
    rv = clib.mysql_options(conn, ffi.C.MYSQL_READ_DEFAULT_GROUP, 'client')
    if rv ~= 0 then
      cr:setError(fmt('mysql_options(MYSQL_READ_DEFAULT_GROUP, \'client\') failed: (%d) %s',
      clib.mysql_errno(conn),
      ffi.string(clib.mysql_error(conn))))
      clib.mysql_close(conn)
      callback(cr)
      return
    end
  end

  -- http://dev.mysql.com/doc/refman/5.0/en/mysql-real-connect.html
  if self.mysql_socket then
    rv = clib.mysql_real_connect(conn,
                                 nil,
                                 self.mysql_username,
                                 self.mysql_password,
                                 nil,
                                 0,
                                 self.mysql_socket,
                                 0)
  else
    rv = clib.mysql_real_connect(conn,
                                 self.mysql_host,
                                 self.mysql_username,
                                 self.mysql_password,
                                 nil,
                                 self.mysql_port,
                                 nil,
                                 0)
  end

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
  for idx, query in pairs(self:getQueries()) do
     if query.kvquery then
       runKeyValueQuery(conn, query.query, cr, clib, query.stat_map)
     else
       runColumnBasedQuery(conn, query.query, cr, clib, query.stat_map)
     end
  end
  -- Issue callback here for any errors/metrics in the query methods above
  callback(cr)
end

local exports = {}
exports.MySQLCheck = MySQLCheck
return exports
