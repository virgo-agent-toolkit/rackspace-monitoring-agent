APP_FILES=$(shell find . -type f -name '*.lua')
LIT_VERSION=2.1.8
TARGET=build/rackspace-monitoring-agent
LUVI?=./luvi
LIT?=./lit
LUVISIGAR?=luvi-sigar
PREFIX?=/usr/bin

all: $(TARGET)

$(LUVISIGAR):
	[ ! -x luvi-sigar ] && $(LIT) get-luvi -o luvi-sigar || exit 0

$(TARGET):  lit $(LUVISIGAR) $(APP_FILES)
	cmake -H. -Bbuild
	cmake --build build

install: $(TARGET)
	install -m 777 $(TARGET) $(PREFIX)/

test: lit $(LUVISIGAR)
	rm -rf tests/tmpdir && mkdir tests/tmpdir
	$(LIT) install
	./luvi-sigar . -m tests/run.lua

clean:
	rm -rf lit luvi luvi-sigar build

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

.PHONY: clean lint package packagerepo packagerepoupload siggen siggenupload install
