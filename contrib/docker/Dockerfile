FROM stackbrew/ubuntu:14.04

RUN apt-get update && \
    apt-get install -y wget && \
    wget -O meta.deb http://meta.packages.cloudmonitoring.rackspace.com/ubuntu-14.04-x86_64/rackspace-cloud-monitoring-meta-stable_1.0_all.deb && \
    dpkg -i meta.deb && \
    apt-get update && \
    apt-get -y install rackspace-monitoring-agent && \
    apt-get -y autoremove && \
    apt-get clean

RUN rm -rf /var/lib/apt/lists/*

RUN apt-get -y autoremove && \
    apt-get clean

CMD ['/usr/bin/rackspace-monitoring-agent']
