Virgo
=====

Virgo is a project for building an on-host agents. The goal is to
provide shared infrastructure for various types of agents.

The first agent to use this infrastructure is the Rackspace Cloud
Monitoring agent.

Join in and build your agent with us.

License
=======

virgo is distributed under the [Apache License 2.0][apache].

[apache]: http://www.apache.org/licenses/LICENSE-2.0.html


Bundles
=======

Bundles take the form [name]-[version].zip, ie:

    monitoring-0.0.1.zip

A command-line argument of '-b' will force a specific bundle directory.

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

Building on a Unix-like Operating System
========================================

    ./configure
    make

Running tests
=============

    make test

Running monitoring agent fixtures server
========================================

The monitoring agent comes with an example fixture server. This will
send the fixtures found in `agents/monitoring/tests/fixtures/` back and
forth between a running agent. You can run a server and agent like this:

     python agents/monitoring/runner.py server_fixture
     python agents/monitoring/runner.py agent_fixture

If you want to have the fixtures server listen on something other than
`127.0.0.1` provide the environment variable `LISTEN_IP="0.0.0.0"`.

Building for Rackspace Cloud Monitoring
=======================================

Rackspace customers: Virgo is the open source project for the Rackspace
Cloud Monitoring agent. Feel free to build your own copy from this
source.

But! Please don't contact Rackspace Support about issues you encounter
with your custom build. We can't support every change people may make
and master might not be fully tested.

Building on RHEL 5.x
====================

Add the EPEL repo and install dependencies

    # rpm -ivh http://mirror.hiwaay.net/pub/epel/5/x86_64/epel-release-5-4.noarch.rpm
    # yum update
    # yum groupinstall 'Development Tools'
    # yum install git python26 gcc44 gcc44-c++

Default to python2.6:

    # ln -s /usr/bin/python2.6 /usr/local/bin/python
    # export PATH=/usr/local/bin:$PATH

Clone the repository:

    # git clone https://github.com/racker/virgo.git

Configure and Build:

    # ./configure
    # CC=gcc44 CXX=g++44 make
    # CC=gcc44 CXX=g++44 make install

Building on Windows
====================

Install the following:

* Windows .NET 4 Framework (Full Framework, not client): http://www.microsoft.com/download/en/details.aspx?displaylang=en&id=17851
* Python 2.7: http://www.python.org/download/releases/2.7.2/
* MSYS Git: http://code.google.com/p/msysgit/ (does not work with cygwin git)
* Windows 7 SDK: https://www.microsoft.com/download/en/details.aspx?id=8279
* VS 2010 C++ Express: http://www.microsoft.com/visualstudio/en-us/products/2010-editions/visual-cpp-express
* VS 2010 SP1: https://www.microsoft.com/download/en/details.aspx?id=23691

Once the dependencies are installed:

    python configure

Now you can open `monitoring-agent.sln` from Visual Studio.

If you wish to compile from the command line, run:

    python tools/build.py build

See also: http://www.chromium.org/developers/how-tos/build-instructions-windows


Hacking
=======
### Change agent entry point

The entry point to the agent defaults to
`modules/monitoring/monitoring-agent.lua`. To change this entry use the flag -e:

    ./monitoring-agent -z monitoring-test.zip -e tests

This example would run `agents/monitoring/tests/init.lua`.

### Making a new release

Virgo version numbers are managed using git tagging. To make a new version
create an annotated tag:

    git tag -a 0.1.1 -m 'release v0.1.1'

Then push the tag to your git repository

    git push --tags

Distro Packages
===============

### RPM

    yum install rpm-build
    make rpm

Find the rpms in out/rpmbuild/RPMS/

### dpkg

    apt-get install devscripts
    make deb

Find the deb in out/debbuild/
