APP_FILES=$(shell find . -type f -name '*.lua')
BINARY_MODULES=binary_modules/$(shell uname -s)_$(shell uname -m)

rackspace-monitoring-agent: lit $(APP_FILES)
	[ -d $(BINARY_MODULES) ] && cp $(BINARY_MODULES)/* .
	./lit make

test: lit
	./rackspace-monitoring-agent tests/run.lua

clean:
	rm -rf rackspace-monitoring-agent lit lit-* luvi

lit:
	curl -L https://github.com/luvit/lit/raw/0.9.7/web-install.sh | sh

lint:
	find . -name "*.lua" | xargs luacheck

.PHONY: clean lint
