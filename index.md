---
layout: default
title: Rackspace Cloud Monitoring Agent
---

What is it?
===========

A tiny service running on your servers which samples system & application metrics, and pushes them to Rackspace Cloud Monitoring where they can be <a href="http://docs.rackspace.com/cm/api/v1.0/cm-devguide/content/alerts-language.html#concepts-alarms-alarm-language">analyzed</a>, <a href="http://blueflood.io/">graphed</a>, and <a href="http://docs.rackspace.com/cm/api/v1.0/cm-devguide/content/service-notification-types-crud.html">alerted on</a>. Your favorite tools (<a href="https://github.com/rackspace-cookbooks/rackspace_cloudmonitoring">Chef</a>, <a href="https://github.com/vickleford/puppet-cloudmonitoring">Puppet</a>, <a href="https://galaxy.ansible.com/list#/roles/855">Ansible</a>, <a href="https://github.com/rgbkrk/salt-states-rackspace-monitoring">Salt</a>, etc…) integrate with us to transparently install & configure monitoring when you provision new servers or deploy new code. You can also do it yourself with <a href="http://www.rackspace.com/blog/monitor-like-a-pro-with-server-side-configuration/">local YAML configurations</a> or via <a href="http://docs.rackspace.com/cm/api/v1.0/cm-devguide/content/service-api-operations.html">our API</a> if you like.

## Monitoring Features

### Metrics

We bundle many <a href="https://github.com/virgo-agent-toolkit/rackspace-monitoring-agent/tree/master/check">fundamental check types</a> into our agent.

* CPU
* Disk
* Filesystem
* Network
* Load Average
* Memory
* Apache
* MySQL
* Redis
* SQL Server
* Windows PerfOS

Each of these reports a variety of metrics about the resource they target.

### Host Info

You can <a href="http://docs.rackspace.com/cm/api/v1.0/cm-devguide/content/service-agent-host_info.html#service-agent-host_info-types">query your connected agents via our API</a> to instantly retrieve <a href="https://github.com/virgo-agent-toolkit/rackspace-monitoring-agent/tree/master/hostinfo">structured data about your hosts</a>. 

### Custom Plugins

Just like the <a href="https://github.com/cloudkick/agent-plugins">Cloudkick agent</a> or Nagios, you can use any tool you like to sample data about your systems, reformat its output into <a href="http://docs.rackspace.com/cm/api/v1.0/cm-devguide/content/appendix-check-types-agent.html#section-ct-agent.plugin">a simple text format</a>, and the monitoring agent will push the metrics into Cloud Monitoring where you can graph and alert on them. We maintain <a href="https://github.com/racker/rackspace-monitoring-agent-plugins-contrib">a repository of custom agent plugins</a> that many developers & sysadmins have contributed. If you don't see what you need there, write your own. It's easy!

### Want new features?

Join us on #cloudmonitoring on <a href="https://freenode.net/">Freenode</a> and share your monitoring ideas with us! We also <a href="https://github.com/virgo-agent-toolkit/rackspace-monitoring-agent"><3 pull requests</a>.

## Technology

The <a href="https://github.com/virgo-agent-toolkit/virgo-base-agent">core agent</a> functionality is carefully written in C, so it is efficient and cross-platform with almost no system dependencies. We embed <a href="http://luvit.io">Luvit</a> so we can use a high-level language to enable rapid iteration on <a href="https://github.com/virgo-agent-toolkit/rackspace-monitoring-agent/blob/master/check/memory.lua">simple, easily-verifiable monitoring code</a>. This idea inspired the <a href="https://github.com/virgo-agent-toolkit">Virgo Agent Toolkit</a> project. 

Much of our monitoring uses <a href="https://support.hyperic.com/display/SIGAR/Home;jsessionid=EE17A264DA80C76BCB7197D6D37129D0">SIGAR</a>, but we also do cool things like using <a href="http://luajit.org/ext_ffi.html">LuaJIT FFI</a> to link against external libraries for monitoring <a href="https://github.com/virgo-agent-toolkit/rackspace-monitoring-agent/blob/master/check/mysql.lua#L54">specific applications</a>.

## Performance

Our monitoring agent uses very little CPU and only about 6 megabytes of RAM (most of this is <a href="http://en.wikipedia.org/wiki/Static_library#Advantages_and_disadvantages">statically linking</a> <a href="https://www.openssl.org/">OpenSSL</a>). Only 3 persistent socket connections are maintained, and we use only the bandwidth necessary to send your metrics. We have over 60k agents installed in heterogenous environments all around the world, and we want to have many more, so we strive to be as lightweight and low-impact as possible.

## Security

Our agent is open-source, so you can review the code yourself for security issues and know that other users of our agent are doing the same. You can compile your own builds, leaving in only the features you like. OpenSSL is statically linked, and we frequently ship updated packages. We sign our packages with GPG. Our outbound connections are secured with TLS. Our agent authenticates our servers using a private Certificate Authority, and connect to only 3 well-known VIPs, so firewall rules are easy to write. Our agent can also use your HTTP proxies to route its traffic outside of your sequestered networks, so your networks can remain secure.

Installing
==========

## … from our packages

We distribute packages for many operating systems at <a href="https://meta.packages.cloudmonitoring.rackspace.com/">https://meta.packages.cloudmonitoring.rackspace.com/</a>.

## … from source

{% highlight bash %}
git clone https://github.com/virgo-agent-toolkit/rackspace-monitoring-agent
cd rackspace-monitoring-agent
git submodule update --init --recursive
./configure && make
make install
{% endhighlight %}

Setup
=====

<a href="http://www.rackspace.com/knowledge_center/article/install-the-cloud-monitoring-agent#Setup">http://www.rackspace.com/knowledge_center/article/install-the-cloud-monitoring-agent#Setup</a>

License
=======

The Monitoring Agent is distributed under the [Apache License 2.0][apache].

[apache]: http://www.apache.org/licenses/LICENSE-2.0.html

