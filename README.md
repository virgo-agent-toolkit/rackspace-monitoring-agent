Rackspace Monitoring Agent
=====

[![Build Status](https://travis-ci.org/virgo-agent-toolkit/rackspace-monitoring-agent.png?branch=master)](https://travis-ci.org/virgo-agent-toolkit/rackspace-monitoring-agent)

The monitoring agent is the first agent to use the infrastructure provided by
[virgo-base-agent](https://github.com/virgo-agent-toolkit/virgo-base-agent)


Installing The Agent
====================

Make sure you have the required packages to build things on your system. EG.
`build-essential`. Please note, if you don't want to compile things and or don't
have too, you can install using the normal "Package" method as outlined
[here](http://www.rackspace.com/knowledge_center/article/install-the-cloud-monitoring-agent).
Otherwise, continue reading this section.


First get the source 

    git clone https://github.com/virgo-agent-toolkit/rackspace-monitoring-agent


Go into the directory that you just created 

    cd rackspace-monitoring-agent


Then get the submodules that you need

    git submodule update --init --recursive


Now configure and make all the things

    ./configure && make 


Now simply install the virgo client by running this last and final command.

    make install

Post installation you will have a new Binary on your system,
`rackspace-monitoring-agent`.  To get the client running on your system please
follow the setup procedure as found
[here](http://www.rackspace.com/knowledge_center/article/install-the-cloud-monitoring-agent#Setup)


License
=======

The Monitoring Agent is distributed under the [Apache License 2.0][apache].

[apache]: http://www.apache.org/licenses/LICENSE-2.0.html


Bundles
=======

The Lua files in this repository are not used directly (nor will they run under
Luvit).  Instead, they must first be bundled into a zip archive which virgo
undertands.  Virgo makes this process easy by taking a flag to configure,
--bundle, which should be set to the directory this repo lives in.  See Virgo
for more information on bundles.

Building for Rackspace Cloud Monitoring
=======================================

Rackspace customers: Virgo is the open source project for the Rackspace
Cloud Monitoring agent. Feel free to build your own copy from this
source.

But! Please don't contact Rackspace Support about issues you encounter
with your custom build. We can't support every change people may make
and master might not be fully tested.

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

The zip file bundle and the binary shipped in an rpm/deb/msi will be
identical. If the binary is 1.4.2 then the bundle will be 1.4.2.

Running tests
=============

Virgo supplies infrastructure for running tests.  Calling make test will launch
Virgo with command line flags set to feed it the testing bundle and with the -e
flag set to tests.

    make test

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

