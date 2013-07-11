Rackspace Monitoring Agent
=====

The monitoring agent is the first agent to use the infrastructure provided by
[virgo](https://github.com/racker/virgo)

License
=======

The Monitoring Agent is distributed under the [Apache License 2.0][apache].

[apache]: http://www.apache.org/licenses/LICENSE-2.0.html


Bundles
=======

The Lua files in this repository are not used directly (nor will they run under Luvit).  Instead, they must first be bundled into a zip archive which virgo undertands.  Virgo makes this process easy by taking a flag to configure, --bundle, which should be set to the directory this repo lives in.  See Virgo for more information on bundles.

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

Virgo supplies infrastructure for running tests.  Calling make test will launch Virgo with command line flags set to feed it the testing bundle and with the -e flag set to tests.

    make test

State Machine Diagram
=====================

![FSM](https://raw.github.com/racker/virgo/master/contrib/fsm.png)

The textual representation of the dot file is generated with Graph-Easy.

https://github.com/ironcamel/Graph-Easy

Command:

    graph-easy --input=contrib/fsm.gv --output=contrib/fsm.txt --as_ascii

