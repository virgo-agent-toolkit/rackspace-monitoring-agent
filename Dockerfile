from	tianon/debian:6.0.7
maintainer	Ryan Phillips <ryan.phillips@rackspace.com>

run     apt-get update
run     apt-get upgrade -y
run	apt-get install -y git build-essential python
run     mkdir /code
add     . /code/virgo
run     cd /code/virgo && git submodule update --init --recursive
run     cd /code/virgo && ./configure && make
# run   cd /code/virgo && make test
