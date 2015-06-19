APP_FILES=$(shell find . -type f -name '*.lua')
LIT_VERSION=2.0.4
TARGET=rackspace-monitoring-agent
LUVI?=./luvi
LIT?=./lit

all: $(TARGET)

$(TARGET): lit $(APP_FILES)
	cmake -H. -Bbuild
	cmake --build build

test: lit
	rm -rf tests/tmpdir && mkdir tests/tmpdir
	$(LIT) install
	$(LUVI) . -m tests/run.lua

clean:
	rm -rf $(TARGET) lit luvi build

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
