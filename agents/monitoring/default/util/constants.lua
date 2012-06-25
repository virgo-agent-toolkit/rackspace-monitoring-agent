local os = require('os')
local path = require('path')

local exports = {}

-- All intervals and timeouts are in milliseconds

exports.CONNECT_TIMEOUT = 6000
exports.SOCKET_TIMEOUT = 10000
exports.HEARTBEAT_INTERVAL_JITTER = 7000

exports.DATACENTER_MAX_DELAY = 5 * 60 * 1000 -- max connection delay
exports.DATACENTER_MAX_DELAY_JITTER = 7000

exports.SRV_RECORD_FAILURE_DELAY = 15 * 1000
exports.SRV_RECORD_FAILURE_DELAY_JITTER = 15 * 1000

exports.DEFAULT_MONITORING_SRV_QUERIES = {
  '_monitoring_agent._tcp.lon3.prod.monitoring.api.rackspacecloud.com',
  '_monitoring_agent._tcp.ord1.prod.monitoring.api.rackspacecloud.com'
}

if os.type() == 'win32' then
  exports.DEFAULT_PERSISTENT_VARIABLE_PATH = './'
else
  exports.DEFAULT_PERSISTENT_VARIABLE_PATH = '/var/lib/rackspace-monitoring-agent'
end

-- Custom plugins related settings

exports.DEFAULT_CUSTOM_PLUGINS_PATH = path.join(exports.DEFAULT_PERSISTENT_VARIABLE_PATH, 'plugins')
exports.DEFAULT_PLUGIN_TIMEOUT = 30 * 1000
exports.PLUGIN_TYPE_MAP = {string = 'string', int = 'int64', float = 'double', gauge = 'gauge'}

return exports
