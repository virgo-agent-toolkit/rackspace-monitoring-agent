from stackbrew/debian
maintainer	Ryan Phillips <ryan.phillips@rackspace.com>

RUN     apt-get update
RUN     apt-get install -y git
RUN     apt-get install -y build-essential
RUN     apt-get install -y python

CMD /bin/bash
