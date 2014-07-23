#!/bin/bash

docker build -t agent .
RUNID=`docker run -d agent /bin/sh -c "while true; do echo hello world; sleep 1; done"`
docker export ${RUNID} | gzip > rackspace-monitoring-agent-root.tar.gz
docker kill ${RUNID}
