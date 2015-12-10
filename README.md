Rackspace Monitoring Agent
=====
[![Throughput Graph](https://graphs.waffle.io/virgo-agent-toolkit/waffle-tracker/throughput.svg)](https://waffle.io/virgo-agent-toolkit/waffle-tracker/metrics)  

[![Build status](https://ci.appveyor.com/api/projects/status/56kkuojwo5nxl5q2/branch/master?svg=true)](https://ci.appveyor.com/project/racker-buildbot/rackspace-monitoring-agent/branch/master)
[![Build Status](https://travis-ci.org/virgo-agent-toolkit/rackspace-monitoring-agent.png?branch=master)](https://travis-ci.org/virgo-agent-toolkit/rackspace-monitoring-agent) [![Stories in Ready](https://badge.waffle.io/virgo-agent-toolkit/rackspace-monitoring-agent.png?label=ready&title=Ready)](https://waffle.io/virgo-agent-toolkit/waffle-tracker)

The monitoring agent is the first agent to use the infrastructure provided by
[virgo-base-agent](https://github.com/virgo-agent-toolkit/virgo-base-agent)


Installing The Agent
====================

Make sure you have the required packages to build things on your system. The
`Dockerfile` will contain the development dependencies.

**Please note, we provide binaries for many platforms. Check out the article at
[http://www.rackspace.com/knowledge_center/article/install-the-cloud-monitoring-agent](http://www.rackspace.com/knowledge_center/article/install-the-cloud-monitoring-agent)
for instructions.**

Otherwise, continue reading this section.

Satisfy pre-requisites:

If you're on windows you may have to either install or find and add certain utilities to your path beforehand.
These are:

 - cmake    - Downloadable from cmake gnu site
 - nmake    - Included in Visual studio/VC/bin but may need to be inserted into your path
 - signtool - Included in Microsoft SDKs/windows/v7.1a/bin but may need to be inserted into your path

On Linux from a fresh install:  

```
apt-get install make cmake
```

Get the source:

    git clone https://github.com/virgo-agent-toolkit/rackspace-monitoring-agent

Go into the directory that you just created:

    cd rackspace-monitoring-agent

Build:

    make

Now simply install the virgo client by running this last and final command:

    make install

After installing on unix systems, there is a new binary called
`rackspace-monitoring-agent`.  To get the client running on your system please
follow the setup procedure as found
[here](http://www.rackspace.com/knowledge_center/article/install-the-cloud-monitoring-agent#Setup)

Host Info Runner
================

The agent has a built in host information runner (similar to OHAI).

```sh
rackspace-monitoring-agent -e hostinfo_runner -x [type]
```
Further documentation for the host informations can be found in the [hostinfo readme](https://github.com/virgo-agent-toolkit/rackspace-monitoring-agent/blob/master/hostinfo/README.md)

License
=======

The Monitoring Agent is distributed under the [Apache License 2.0][apache].

[apache]: http://www.apache.org/licenses/LICENSE-2.0.html


Building for Rackspace Cloud Monitoring
=======================================

Rackspace customers: Virgo is the open source project for the Rackspace
Cloud Monitoring agent. Feel free to build your own copy from this
source.

But! Please don't contact Rackspace Support about issues you encounter
with your custom build.

Versioning
==========

The agent is versioned with a three digit dot seperated "semantic
version" with the template being x.y.z. An example being e.g. 1.4.2. The
rough meaning of each of these parts are:

- major version numbers will change when we make a backwards
  incompatible change to the bundle format. Binaries can only run
  bundles with identical major version numbers. e.g. a binary of version
  2.3.1 can only run bundles starting with 2.

- minor version numbers will change when we make backwards compatible
  changes to the bundle format. Binaries can only run bundles with minor
  versions that are greater than or equal to the bundle version. e.g. a
  binary of version 2.3.1 can run a 2.3.4 bundle but not a 2.2.1 bundle.

- patch version numbers will change everytime a new bundle is released.
  It has no semantic meaning to the versioning.

Running tests
=============

Virgo supplies infrastructure for running tests.  Calling make test will launch
Virgo with command line flags set to feed it the testing bundle and with the -e
flag set to tests.

    make test

You can also run an individual test module:

    TEST_MODULE=net make test

Running tests on docker
=======================

This only needs to be done once per terminal session:

```
docker-machine create agent
eval $(docker-machine env agent)
```

Use `docker-compose` to build and run the tests:

```
docker-compose run build make clean
docker-compose run build make
docker-compose run build test
```

Configuration File Parameters
=============================

    monitoring_token [token]         - (required) The authentication token.
    monitoring_id [agent_id]         - (optional) The Agent's monitoring_id
                                       (default: Instance ID (Xen) or Cloud-Init ID)
    monitoring_snet_region [region]  - (optional) Enable Service Net endpoints
                                       (region: dfw, ord, lon, syd, hkg, iad)
    monitoring_endpoints             - (optional) Force IP and Port, comma
                                       delimited
    monitoring_proxy_url [url]       - (optional) Use a HTTP Proxy
                                       Must support CONNECT on port 443.
                                       Additionally, HTTP_PROXY and HTTPS_PROXY
                                       are honored.
    monitoring_query_endpoints [queries] - (optional) SRV queries comma
                                            delimited

Exit Codes
==========

    1 unknown error
    2 config file fail
    3 already running

Signals
=======

    SIGUSR1: Force GC
    SIGUSR2: Toggle Debug

