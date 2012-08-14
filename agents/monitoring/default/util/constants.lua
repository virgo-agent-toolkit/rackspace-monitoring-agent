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

exports.SETUP_AUTH_TIMEOUT = 15 * 1000
exports.SETUP_AUTH_CHECK_INTERVAL = 2 * 1000

if process.env.STAGING then
  exports.DEFAULT_MONITORING_SRV_QUERIES = {
    '_monitoringagent._tcp.dfw1.stage.monitoring.api.rackspacecloud.com',
    '_monitoringagent._tcp.ord1.stage.monitoring.api.rackspacecloud.com',
    '_monitoringagent._tcp.lon3.stage.monitoring.api.rackspacecloud.com'
  }
else
  exports.DEFAULT_MONITORING_SRV_QUERIES = {
    '_monitoringagent._tcp.dfw1.prod.monitoring.api.rackspacecloud.com',
    '_monitoringagent._tcp.ord1.prod.monitoring.api.rackspacecloud.com',
    '_monitoringagent._tcp.lon3.prod.monitoring.api.rackspacecloud.com'
  }
end

if os.type() == 'win32' then
  exports.DEFAULT_PERSISTENT_VARIABLE_PATH = './'
else
  exports.DEFAULT_PERSISTENT_VARIABLE_PATH = '/var/lib/rackspace-monitoring-agent'
end

if os.type() == 'win32' then
  exports.DEFAULT_CONFIG_PATH = path.join('.', virgo.default_config_filename)
else
  exports.DEFAULT_CONFIG_PATH = virgo.default_config_path
end

-- Custom plugins related settings

exports.DEFAULT_CUSTOM_PLUGINS_PATH = '/usr/lib/rackspace-monitoring-agent/plugins'
exports.DEFAULT_PLUGIN_TIMEOUT = 30 * 1000
exports.PLUGIN_TYPE_MAP = {string = 'string', int = 'int64', float = 'double', gauge = 'gauge'}

exports.CRASH_REPORT_URL = 'https://monitoring.api.rackspacecloud.com/agent-crash-report'

return exports
