local exports = {}

-- All intervals and timeouts are in milliseconds

exports.GC_INTERVAL = 5 * 1000

exports.CONNECT_TIMEOUT = 6000
exports.SOCKET_TIMEOUT = 10000
exports.PING_INTERVAL_JITTER = 7000

exports.DATACENTER_MAX_DELAY = 5 * 60 * 1000 -- max connection delay
exports.DATACENTER_MAX_DELAY_JITTER = 7000

exports.SRV_RECORD_FAILURE_DELAY = 15 * 1000
exports.SRV_RECORD_FAILURE_DELAY_JITTER = 15 * 1000
return exports
