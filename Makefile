APP_FILES=$(shell find . -type f -name '*.lua')
TARGET=rackspace-monitoring-agent

all: $(TARGET)

rackspace-monitoring-agent: binary_modules/sigar.so lit $(APP_FILES)
	./lit make

binary_modules/sigar.so:
	mkdir -p binary_modules
	[ -d lua-sigar ] || git clone --recursive https://github.com/virgo-agent-toolkit/lua-sigar
	cd lua-sigar && cmake . && make
	cp lua-sigar/sigar.so binary_modules

test: lit
	./rackspace-monitoring-agent tests/run.lua

clean:
	rm -rf rackspace-monitoring-agent lit* luvi lua-sigar binary_modules

lit:
	curl -L https://github.com/luvit/lit/raw/0.9.7/web-install.sh | sh

lint:
	find . -name "*.lua" | xargs luacheck

.PHONY: clean lint
