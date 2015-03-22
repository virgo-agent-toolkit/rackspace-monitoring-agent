return {
  name = "rackspace-monitoring-agent",
  version = "1.9.0",
  dependencies = {
    "rphillips/options@0.0.5",
    "virgo-agent-toolkit/rackspace-monitoring-client@0.3.1",
    "virgo-agent-toolkit/virgo@0.11.3",
  },
  files = {
    "**.lua",
    "libs/$OS-$ARCH/*",
    "!*.ico",
    "!CHANGELOG",
    "!Dockerfile",
    "!LICENSE*",
    "!Makefile",
    "!README*",
    "!contrib",
    "!examples",
    "!lit",
    "!lit-*",
    "!luvi",
    "!static",
    "!tests",
    "!lua-sigar",
    "!rackspace-monitoring-agent",
  }
}
