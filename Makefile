APP_FILES=$(shell find . -type f -name '*.lua')
TARGET=rackspace-monitoring-agent

all: $(TARGET)

rackspace-monitoring-agent: modules lit $(APP_FILES)
	./lit make

modules: libs/sigar.so

libs/sigar.so:
	mkdir -p libs
	[ -d lua-sigar ] || git clone --recursive https://github.com/virgo-agent-toolkit/lua-sigar
	cd lua-sigar && cmake . && make && cp sigar.so ../libs

test: lit
	./rackspace-monitoring-agent tests/run.lua

clean:
	rm -rf rackspace-monitoring-agent lit lit-* luvi

lit:
	curl -L https://github.com/luvit/lit/raw/0.10.4/get-lit.sh | sh

lint:
	find . -name "*.lua" | xargs luacheck

.PHONY: clean lint
