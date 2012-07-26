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

     python agents/monitoring/runner server_fixture
     python agents/monitoring/runner agent_fixture

Building on RHEL 5.x
====================

Add the EPEL repo and install dependencies

    # rpm -ivh http://download.fedoraproject.org/pub/epel/5/x86_64/epel-release-5-4.noarch.rpm
    # yum update
    # yum groupinstall 'Development Tools'
    # yum install git python26 gcc44 gcc44-c++

Default to python2.6:

     ln -s /usr/bin/python2.6 /usr/local/bin/python
     export PATH=/usr/local/bin:$PATH

The certificate bundle in RHEL 5.x is old. We upgrade it in the next step.

     curl http://curl.haxx.se/ca/cacert.pem -o /etc/pki/tls/certs/ca-bundle.crt

Clone the repository:

     git clone https://github.com/racker/virgo.git

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
