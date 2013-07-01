local os = require('os')
local misc = require('./misc')
local path = require('path')

local exports = {}

exports.DEFAULT_CHANNEL = 'stable'

-- All intervals and timeouts are in milliseconds

exports.CONNECT_TIMEOUT = 6000
exports.SOCKET_TIMEOUT = 10000
exports.HEARTBEAT_INTERVAL_JITTER_MULTIPLIER = 7

exports.UPGRADE_INTERVAL = 86400000 -- 24hrs
exports.UPGRADE_INTERVAL_JITTER = 3600000 -- 1 hr

exports.RATE_LIMIT_SLEEP = 5000
exports.RATE_LIMIT_RETURN_CODE = 2

exports.DATACENTER_FIRST_RECONNECT_DELAY = 41 * 1000 -- initial datacenter delay
exports.DATACENTER_FIRST_RECONNECT_DELAY_JITTER = 37 * 1000 -- initial datacenter jitter

exports.DATACENTER_RECONNECT_DELAY = 5 * 60 * 1000 -- max connection delay
exports.DATACENTER_RECONNECT_DELAY_JITTER = 17 * 1000

exports.SRV_RECORD_FAILURE_DELAY = 13 * 1000
exports.SRV_RECORD_FAILURE_DELAY_JITTER = 37 * 1000

exports.SETUP_AUTH_TIMEOUT = 45 * 1000
exports.SETUP_AUTH_CHECK_INTERVAL = 2 * 1000

exports.SHUTDOWN_UPGRADE = 1
exports.SHUTDOWN_RATE_LIMIT = 2
exports.SHUTDOWN_RESTART = 3

if misc.isStaging() then
  exports.DEFAULT_MONITORING_SRV_QUERIES = {
    '_monitoringagent._tcp.dfw1.stage.monitoring.api.rackspacecloud.com',
    '_monitoringagent._tcp.ord1.stage.monitoring.api.rackspacecloud.com',
    '_monitoringagent._tcp.lon3.stage.monitoring.api.rackspacecloud.com'
  }

  exports.SNET_MONITORING_TEMPLATE_SRV_QUERIES = {
      '_monitoringagent._tcp.snet-${region}-region0.stage.monitoring.api.rackspacecloud.com',
      '_monitoringagent._tcp.snet-${region}-region1.stage.monitoring.api.rackspacecloud.com',
      '_monitoringagent._tcp.snet-${region}-region2.stage.monitoring.api.rackspacecloud.com'
  }
else
  exports.DEFAULT_MONITORING_SRV_QUERIES = {
    '_monitoringagent._tcp.dfw1.prod.monitoring.api.rackspacecloud.com',
    '_monitoringagent._tcp.ord1.prod.monitoring.api.rackspacecloud.com',
    '_monitoringagent._tcp.lon3.prod.monitoring.api.rackspacecloud.com'
  }

  exports.SNET_MONITORING_TEMPLATE_SRV_QUERIES = {
    '_monitoringagent._tcp.snet-${region}-region0.prod.monitoring.api.rackspacecloud.com',
    '_monitoringagent._tcp.snet-${region}-region1.prod.monitoring.api.rackspacecloud.com',
    '_monitoringagent._tcp.snet-${region}-region2.prod.monitoring.api.rackspacecloud.com'
  }

end

exports.VALID_SNET_REGION_NAMES = {
  'dfw',
  'ord',
  'lon',
  'syd',
  'hkg',
  'iad'
}


local PERSISTENT_DIR = virgo_paths.get(virgo_paths.VIRGO_PATH_PERSISTENT_DIR)
local EXE_DIR = virgo_paths.get(virgo_paths.VIRGO_PATH_EXE_DIR)
local CONFIG_DIR = virgo_paths.get(virgo_paths.VIRGO_PATH_CONFIG_DIR)
local LIBRARY_DIR = virgo_paths.get(virgo_paths.VIRGO_PATH_LIBRARY_DIR)
local RUNTIME_DIR = virgo_paths.get(virgo_paths.VIRGO_PATH_RUNTIME_DIR)
local BUNDLE_DIR = virgo_paths.get(virgo_paths.VIRGO_PATH_BUNDLE_DIR)


exports.DEFAULT_PERSISTENT_VARIABLE_PATH = path.join(PERSISTENT_DIR, 'variables')
exports.DEFAULT_CONFIG_PATH = path.join(CONFIG_DIR, 'rackspace-monitoring-agent.cfg')
exports.DEFAULT_STATE_PATH = path.join(RUNTIME_DIR, 'states')
exports.DEFAULT_DOWNLOAD_PATH = path.join(RUNTIME_DIR, 'downloads')
exports.DEFAULT_RUNTIME_PATH = RUNTIME_DIR

exports.DEFAULT_VERIFIED_BUNDLE_PATH = BUNDLE_DIR
exports.DEFAULT_UNVERIFIED_BUNDLE_PATH = path.join(exports.DEFAULT_DOWNLOAD_PATH, 'unverified')
exports.DEFAULT_VERIFIED_EXE_PATH = EXE_DIR
exports.DEFAULT_UNVERIFIED_EXE_PATH = path.join(exports.DEFAULT_DOWNLOAD_PATH, 'unverified')
exports.DEFAULT_PID_FILE_PATH = '/var/run/rackspace-monitoring-agent.pid'

-- Custom plugins related settings

exports.DEFAULT_CUSTOM_PLUGINS_PATH = path.join(LIBRARY_DIR, 'plugins')
exports.DEFAULT_PLUGIN_TIMEOUT = 30 * 1000
exports.PLUGIN_TYPE_MAP = {string = 'string', int = 'int64', float = 'double', gauge = 'gauge'}

exports.CRASH_REPORT_URL = 'https://monitoring.api.rackspacecloud.com/agent-crash-report'

return exports
