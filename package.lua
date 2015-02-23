return {
  name = "rackspace-monitoring-agent",
  version = "1.9.0",
  dependencies = {
    "virgo-agent-toolkit/virgo@0.10.2",
    "rphillips/options@v0.0.5",
  },
  files = {
    "**.lua",
    "*.so",
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
    "!rackspace-monitoring-agent",
    "!binary_modules/**"
  }
}
