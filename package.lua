return {
  name = "rackspace-monitoring-agent",
  version = "2.1.15",
  luvi = {
    version = "2.3.2-sigar",
    flavor = "sigar",
    url = "https://github.com/virgo-agent-toolkit/luvi/releases/download/v%s-sigar/luvi-%s-%s"
  },
  dependencies = {
    "rphillips/options@0.0.5",
    "virgo-agent-toolkit/rackspace-monitoring-client@0.3",
    "virgo-agent-toolkit/virgo@2",
  },
  files = {
    "**.lua",
    "!tests",
    "!contrib",
  }
}
