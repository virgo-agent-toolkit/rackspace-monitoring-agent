from debian
maintainer	Ryan Phillips <ryan.phillips@rackspace.com>

RUN apt-get update && \
    apt-get install -y git build-essential cmake

CMD /bin/bash
