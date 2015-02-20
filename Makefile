APP_FILES=$(shell find . -type f -name '*.lua')
BIN_ROOT=lit/luvi-binaries/$(shell uname -s)_$(shell uname -m)

rackspace-monitoring-agent: lit $(APP_FILES)
	./lit make

test: lit
	./rackspace-monitoring-agent tests/run.lua

clean:
	rm -rf rackspace-monitoring-agent lit lit-* luvi

lit:
	curl -L https://github.com/luvit/lit/raw/0.9.4/web-install.sh | sh

lint:
	find . -name "*.lua" | xargs luacheck

.PHONY: clean lint
