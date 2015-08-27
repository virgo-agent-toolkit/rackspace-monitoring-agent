# Host Info check documentation

## What are hostinfo checks?

Host information checks are a special class of checks that are used to fetch data on demand.   
The normal checks at root/checks are tied to the larger Rackspace monitoring eco-systems alarming and alerting feature  
and are automatically scheduled.   
The hostinfo checks are not.  
Currently it is not possible to configure alarms and alerts via the various frontends.  

## Why hostinfo checks?

So what are they good for?  
They're great for fetching data on demand.  
Which is great if you want to pipe data about the host to other services or applications.  
So in essence these checks exist to periodically fetch data about large clusters of servers with the granularity of  
individual computers for things like information dashboards built with Kibana, or service helper software that generate 
opinions/suggestions based on the status of a system.  
There are also more hostinfo checks than regular checks and creating and integrating a hostinfo check is theoretically  
easier than creating and integrating a normal check into the rackspace monitoring ecosystem.  

## Commands

There's a few ways to run hostinfo checks on a remote box.  

1) Through the monitoring system, remotely, you can make a curl request:
```sh
curl -H 'X-Auth-Token: <auth token>' -H 'X-Tenant-Id: <tenant id>'  https://monitoring.api.rackspacecloud.com/v1.0/agents/<agent_id>/host_info/<hostinfo_type>
```
Of course the above method can also be salvaged to programmatically allow usage from a user written script since all it  
 does is use the rackspace monitoring API.  
 
2) SSHd into the box itself (Caveat: run these commands with sudo since the agent usually has super user privileges when  
  run via the monitoring system).
```sh
rackspace-monitoring-agent -e hostinfo_runner -x <hostinfo type>
```
or pipe it through jq if you have it installed to get pretty output. The output is or should be valid json. 
```sh
apt-get install jq
rackspace-monitoring-agent -e hostinfo_runner -x packages | jq .
```

Additionally the API on the box itself has the ability to generate and write debug info to a file for all the hostinfo checks:  
```
rackspace-monitoring-agent -e hostinfo_runner -d debug.txt
```
The above command will generate a debug.txt file at the root directory of the rackspace-monitoring-agent.
An example of this file with example outputs of all of the hostinfos can be found at [debug.txt](https://github.com/virgo-agent-toolkit/rackspace-monitoring-agent/blob/master/hostinfo/debug.tx)

## Test

To test only the hostinfos you can run the test runner from the root dir with an environment variable like so: 
```sh
TEST_MODULE=HOSTINFO make test
```

## Current list of available hostinfo checks

The best resource for figuring out the most uptodate list of available hostinfos is to look at [all.lua](https://github.com/virgo-agent-toolkit/rackspace-monitoring-agent/blob/master/hostinfo/all.lua)

As of this writing, here is the list:

```
 iptables  
 ip6tables  
 autoupdates  
 passwd  
 pam  
 cron  
 kernel_modules  
 cpu  
 disk  
 filesystem  
 login  
 memory  
 network  
 nil  
 packages  
 procs  
 system  
 who  
 date  
 sysctl  
 sshd  
 fstab  
 fileperms  
 services  
 deleted_libs  
 cve  
 last_logins  
 remote_services  
 ip4routes  
 ip6routes
 connection
 apache2
```

## Notes for developers

PRs are always welcome. Few tips:  
There's currently three over-arching classes of hostinfo checks.  
Those that read files, these use the read function in hostinfo/misc.lua  
Those that spawn shell commands to retrieve data, these use the run function in hostinfo/misc.lua  
The last type use a library called [Sigar (System Information Gatherer And Reporter)](https://github.com/hyperic/sigar)  
 which has an invaluable API for efficiently retrieving system information for things like RAM and CPU usage.  
There are some hostinfos that straddle classes as well.  

The hostinfos that use run or read have a streaming interface, with a readStream or childStream being passed to a transform  
stream which parses and collects data.  
At the moment 100% of the parsers or transform streams have tests.  
The test runner is located in [<root>/tests/test-hostinfo.lua](https://github.com/virgo-agent-toolkit/rackspace-monitoring-agent/blob/master/tests/test-hostinfo.lua)  
with sample inputs and outputs that they're tested against located in [<root>/static/tests/hostinfo](https://github.com/virgo-agent-toolkit/rackspace-monitoring-agent/tree/master/static/tests/hostinfo)  

A common question that arises is why lua?
One of the main reasons behind it is that the [luvit](https://luvit.io/) framework we use allows us to do blazing fast async i/o and offers an API  
similiar to node, which allows luvit developers to use pre-existing node docs and community questions to their own  
benefit.   
The other reason is that lua is cross platform and works on embedded devices and due to use therein has been optimized to  
leave a very small footprint, far smaller than node.  
