from debian:8
maintainer Ryan Phillips <ryan.phillips@rackspace.com>

RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get install -y git build-essential cmake curl

RUN mkdir -p /src
WORKDIR /src

CMD /bin/bash
