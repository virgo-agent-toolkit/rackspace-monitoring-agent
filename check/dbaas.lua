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

local stat_map = {
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
  -- show variables mappings
  query_cache_size = { type = 'uint64', alias = 'qcache.size', unit = 'bytes'},
}

function DBaaSMySQLCheck:getStatMap()
   return stat_map
end

function DBaaSMySQLCheck:getType()
  return 'agent.dbaas_mysql'
end

function DBaaSMySQLCheck:getQueries()
   return {'show status', 'show variables'}
end

local exports = {}
exports.DBaaSMySQLCheck = DBaaSMySQLCheck
return exports
