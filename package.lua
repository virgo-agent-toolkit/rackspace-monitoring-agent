return {
  name = "rackspace-monitoring-agent",
  version = "2.0.5",
  dependencies = {
    "rphillips/options@0.0.5",
    "virgo-agent-toolkit/rackspace-monitoring-client@0.3",
    "virgo-agent-toolkit/virgo@0.14",
  },
  files = {
    "**.lua",
    "libs/$OS-$ARCH/*",
  }
}
