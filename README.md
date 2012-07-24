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
