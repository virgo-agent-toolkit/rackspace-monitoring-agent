APP_FILES=$(shell find . -type f -name '*.lua')
TARGET=rackspace-monitoring-agent

all: $(TARGET)

$(TARGET): lit $(APP_FILES)
	./lit make

test: lit
	./$(TARGET) -e tests

clean:
	rm -rf $(TARGET) lit

lit:
	curl -L https://github.com/luvit/lit/raw/1.0.2/get-lit.sh | sh

lint:
	find . -name "*.lua" | xargs luacheck

package-rpm: $(TARGET)
	cmake -H. -Bbuild -DWithPackageRPM=ON
	cmake --build build -- package

package-deb: $(TARGET)
	cmake -H. -Bbuild -DWithPackageDEB=ON
	cmake --build build -- package

.PHONY: clean lint
