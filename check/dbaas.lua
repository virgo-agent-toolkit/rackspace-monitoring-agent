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

local ffi = require('ffi')

local fmt = require('string').format

local SubProcCheck = require('./base').SubProcCheck
local CheckResult = require('./base').CheckResult
local MySQLCheck = require('mysql').MySQLCheck
local DBaaSMySQLCheck = MySQLCheck:extend()

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

replication_stat_map = {
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

function DBaaSMySQLCheck:getType()
  return 'agent.dbaas_mysql'
end

function DBaaSMySQLCheck:getQueries()
   return { replication_query = { query = 'show slave status', stat_map = replication_stat_map, kvquery = false },
            status_query = { query = "show status", stat_map = status_stat_map, kvquery = true },
            variables_query = { query = 'show variables', stat_map = variables_stat_map, kvquery = true },
   }
end

local exports = {}
exports.DBaaSMySQLCheck = DBaaSMySQLCheck
return exports
