APP_FILES=$(shell find . -type f -name '*.lua')
LIT_VERSION=1.1.8
TARGET=rackspace-monitoring-agent

all: $(TARGET)

$(TARGET): lit $(APP_FILES)
	./lit make

test: lit
	rm -rf tests/tmpdir && mkdir tests/tmpdir
	./lit install
	./luvi . -m tests/run.lua

clean:
	rm -rf $(TARGET) lit luvi

lit:
	curl -L https://github.com/luvit/lit/raw/${LIT_VERSION}/get-lit.sh | sh

lint:
	find . ! -path './deps/**' ! -path './tests/**' -name '*.lua' | xargs luacheck

package:
	cmake -H. -Bbuild
	cmake --build build -- package

packagerepo:
	cmake --build build -- packagerepo

packagerepoupload:
	cmake --build build -- packagerepoupload

siggen:
	cmake --build build -- siggen

siggenupload:
	cmake --build build -- siggenupload

.PHONY: clean lint package packagerepo
