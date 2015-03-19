APP_FILES=$(shell find . -type f -name '*.lua')
TARGET=rackspace-monitoring-agent

all: $(TARGET)

rackspace-monitoring-agent: lit $(APP_FILES)
	./lit make

test: lit
	./rackspace-monitoring-agent -e tests

clean:
	rm -rf rackspace-monitoring-agent lit lit-* luvi

lit:
	curl -L https://github.com/luvit/lit/raw/1.0.2/get-lit.sh | sh

lint:
	find . -name "*.lua" | xargs luacheck

.PHONY: clean lint
