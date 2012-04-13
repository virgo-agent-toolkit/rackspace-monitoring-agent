local exports = {}
exports.CONNECT_TIMEOUT = 6000
exports.SOCKET_TIMEOUT = 10000
exports.PING_INTERVAL_JITTER = 7000

exports.DATACENTER_MAX_DELAY = 5 * 60 * 1000 -- max connection delay
exports.DATACENTER_MAX_DELAY_JITTER = 7000
return exports
