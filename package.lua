return {
  name = "rackspace-monitoring-agent",
  version = "1.9.0",
  dependencies = {
    "virgo-agent-toolkit/virgo@0.10.7",
    "rphillips/options@v0.0.5",
  },
  files = {
    "**.lua",
    "**.so",
    "**.dll",
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
