Developer Guide
===============
This contributing guide focuses on all the things/steps needed for a Developer setup and Debugging.

Repository getting used for Agent Build
=======================================
Make sure you have access to all the mentioned below because they are related to agent build and getting used.
- [Buildbot](https://github.com/rax-maas/buildbot) - this is the buildbot project getting used for agent builds under directory [master_agentbuild_cm](https://github.com/rax-maas/buildbot/tree/master/master_agentbuild_cm).
- [rackspace-monitoring-agent-buildbot-builder](https://github.com/virgo-agent-toolkit/rackspace-monitoring-agent-buildbot-builder) - this is the agnet builder repo in which we have steps defined for agent build on both unix and windows machine.
- [ele-agent-meta-packages](https://github.com/rax-maas/ele-agent-meta-packages) - this is used to create generalized package of agent build.
- [ele-agent-repo-distribution](https://github.com/rax-maas/ele-agent-repo-distribution) - this application is used to manage agent releases.
- [ele-agent-build-slaves](https://github.com/rax-maas/ele-agent-build-slaves) - this repo is getting used we used to provision via ansible. But I doubt we are using this repo now.

Most commonly used wiki's:
==========================
- [Provision new Agent Build Server](https://github.com/rax-maas/ele-kb/issues/97#issue-149967304)
- [Deploy a new agent release](https://github.com/rax-maas/ele-kb/issues/120#issue-161317935)
- [Agent Buildbot URL](https://agentbuild.cm.k1k.me/grid)
- [How to access windows buildslaves](https://github.com/rax-maas/ele-kb/issues/223)
- [Agent Build and Package Infrastructure](https://github.com/rax-maas/ele/wiki/Agent-Build-and-Package-Infrastructure)
- [Rackspace Cloud Monitoring Meta Packages](https://meta.packages.cloudmonitoring.rackspace.com)
- [Install & Configure the agent](https://docs.rackspace.com/docs/rackspace-monitoring/v1/getting-started/install-configure)
- [Troubleshoot the Rackspace Monitoring Agent](https://docs.rackspace.com/support/how-to/troubleshooting-the-rackspace-monitoring-agent/)

Agent Build
===========
While doing agent build from buildbot, we need to do two type of build for a specific OS(on which we need to do the build):
- agent2* - this uses code from rackspace-monitoring-agent-buildbot-builder repo.
- meta* - this uses code from ele-agent-meta-packages build.
- agent-installer* - this build also exist but no longer needed. So you can skip this one.

Docker setup to run Agent build
===============================
We did docker setup which will run both the agent builds when we run the docker container.
This Dockerfile file is defined in [rackspace-monitoring-agent-buildbot-builder](https://github.com/virgo-agent-toolkit/rackspace-monitoring-agent-buildbot-builder) project. 

**Satisfy pre-requisites for Docker run:**
- rclone.conf file - this file has all the credential to copy the build from local server to our rackspace cloud.
- server.key file - RSA key file getting used in agent build.
- agent-package-signing-key.txt file - GPG private key file which is imported when we run the docker container.
If you don't have any of these file, please reach out to team & get it.

**Steps to Run Docker Build**
1. Get the source:
```aidl
git clone git@github.com:virgo-agent-toolkit/rackspace-monitoring-agent-buildbot-builder.git
```
2. Go into the directory that you just created:
```aidl
cd rackspace-monitoring-agent-buildbot-builder
```
3. Make image from docker file.
```aidl
docker build -t agentbuild .
```
4. Run Docker container. Modify the mounted file path according to you the location on your machine (I had kept all the files in project directory itself).
```aidl
docker run --rm -it -v $PWD:/agent2 -v $PWD/rclone.conf:/root/.config/rclone/rclone.conf -v $PWD/agent-package-signing-key.txt:/tmp/agent-package-signing-key.txt -v $PWD/server.key:/root/server.key agentbuild
```
5. If you want to keep the shell connected for Docker, uncomment last line **/bin/bash "$@"** in entrypoint.sh file.

Debugging a Test Case
=====================
To debug a test case, we can simply run docker container as mentioned above by keeping the shell connected (change mentioned in step no 5).

1. Switch to monitoring agent directory in Docker container:
```aidl
cd /agent2/src/rackspace-monitoring-agent
```
2. Run Test to verify:
```aidl
./luvi-sigar . -m tests/run.lua 
```

