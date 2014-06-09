from debian
maintainer	Ryan Phillips <ryan.phillips@rackspace.com>

RUN apt-get update && \
    apt-get install -y git build-essential python

CMD /bin/bash
