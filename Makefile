APP_FILES=$(shell find . -type f -name '*.lua')
BINARY_MODULES=binary_modules/$(shell uname -s)_$(shell uname -m)
TARGET=rackspace-monitoring-agent

all: $(TARGET)

rackspace-monitoring-agent: modules lit $(APP_FILES)
	[ -d $(BINARY_MODULES) ] && cp $(BINARY_MODULES)/* .
	./lit make

modules: modules/sigar.so

modules/sigar.so:
	mkdir -p modules
	git clone --recursive https://github.com/virgo-agent-toolkit/lua-sigar
	cd lua-sigar && cmake . && make
	cp lua-sigar/sigar.so modules

test: lit
	./rackspace-monitoring-agent tests/run.lua

clean:
	rm -rf rackspace-monitoring-agent lit lit-* luvi

lit:
	curl -L https://github.com/luvit/lit/raw/0.9.7/web-install.sh | sh

lint:
	find . -name "*.lua" | xargs luacheck

.PHONY: clean lint
