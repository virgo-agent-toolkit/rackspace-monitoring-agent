local ConstantsCtx = require('/base/util/constants_ctx').ConstantsCtx
local path = require('path')

local constants = ConstantsCtx:new()

local SNET_REGIONS = {
  'dfw',
  'ord',
  'lon',
  'syd',
  'hkg',
  'iad'
}

local LIBRARY_DIR = virgo_paths.get(virgo_paths.VIRGO_PATH_LIBRARY_DIR)
constants:setGlobal('DEFAULT_CUSTOM_PLUGINS_PATH', path.join(LIBRARY_DIR, 'plugins'))
constants:setGlobal('DEFAULT_PLUGIN_TIMEOUT', 60 * 1000)
constants:setGlobal('PLUGIN_TYPE_MAP', {string = 'string', int = 'int64', float = 'double', gauge = 'gauge'})
constants:setGlobal('CRASH_REPORT_URL', 'https://monitoring.api.rackspacecloud.com/agent-crash-report')
constants:setGlobal('DEFAULT_PID_FILE_PATH', '/var/run/rackspace-monitoring-agent.pid')
constants:setGlobal('VALID_SNET_REGION_NAMES', SNET_REGIONS)

constants:setGlobal('DEFAULT_MONITORING_SRV_QUERIES_STAGING', {
  '_monitoringagent._tcp.dfw1.stage.monitoring.api.rackspacecloud.com',
  '_monitoringagent._tcp.ord1.stage.monitoring.api.rackspacecloud.com',
  '_monitoringagent._tcp.lon3.stage.monitoring.api.rackspacecloud.com'
})

constants:setGlobal('SNET_MONITORING_TEMPLATE_SRV_QUERIES_STAGING', {
  '_monitoringagent._tcp.snet-${region}-region0.stage.monitoring.api.rackspacecloud.com',
  '_monitoringagent._tcp.snet-${region}-region1.stage.monitoring.api.rackspacecloud.com',
  '_monitoringagent._tcp.snet-${region}-region2.stage.monitoring.api.rackspacecloud.com'
})

constants:setGlobal('DEFAULT_MONITORING_SRV_QUERIES', {
  '_monitoringagent._tcp.dfw1.prod.monitoring.api.rackspacecloud.com',
  '_monitoringagent._tcp.ord1.prod.monitoring.api.rackspacecloud.com',
  '_monitoringagent._tcp.lon3.prod.monitoring.api.rackspacecloud.com'
})

constants:setGlobal('SNET_MONITORING_TEMPLATE_SRV_QUERIES', {
  '_monitoringagent._tcp.snet-${region}-region0.prod.monitoring.api.rackspacecloud.com',
  '_monitoringagent._tcp.snet-${region}-region1.prod.monitoring.api.rackspacecloud.com',
  '_monitoringagent._tcp.snet-${region}-region2.prod.monitoring.api.rackspacecloud.com'
})

return constants
