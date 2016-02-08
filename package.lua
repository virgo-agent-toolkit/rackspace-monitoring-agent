return {
  name = "rackspace-monitoring-agent",
  version = "2.4.1",
  luvi = {
    version = "2.6.0-sigar",
    flavor = "sigar",
    url = "https://github.com/virgo-agent-toolkit/luvi/releases/download/v%s-sigar/luvi-%s-%s"
  },
  dependencies = {
    "rphillips/options@0.0.5",
    "virgo-agent-toolkit/rackspace-monitoring-client@0.3",
    "virgo-agent-toolkit/virgo@2",
    "kaustavha/luvit-walk@1",
  },
  files = {
    "**.lua",
    "!tests",
    "!contrib",
  }
}
