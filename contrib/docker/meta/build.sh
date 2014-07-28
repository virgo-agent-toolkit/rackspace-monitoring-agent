#!/bin/bash

docker build -t agent .

OUTPUT_FILE=rackspace-monitoring-agent-root.tar.gz
# Create a UUID to identify the build
CONTAINER_UUID=`uuidgen`

docker run agent echo $CONTAINER_UUID
CONTAINER=`docker ps -a --no-trunc |grep $CONTAINER_UUID|awk '{print $1}'|head -n1`
echo $CONTAINER
docker export $CONTAINER | gzip > ${OUTPUT_FILE}
docker rm $CONTAINER
