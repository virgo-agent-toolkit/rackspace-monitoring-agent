BUILDTYPE ?= Debug

DESTDIR ?=
BINDIR = ${DESTDIR}/usr/bin
SHAREDIR = ${DESTDIR}/usr/share/rackspace-monitoring-agent
ETCDIR = ${DESTDIR}/etc

zip_files = monitoring.zip monitoring-test.zip
sig_files = $(zip_files:%.zip=%.zip.sig)

%.zip:
	-ln -fs out/${BUILDTYPE}/$@ $@

%.zip.sig: $(zip_files)
	openssl dgst -sign tests/ca/server.key.insecure $(patsubst %.zip.sig, %.zip, $@) > out/${BUILDTYPE}/$@
	-ln -fs out/${BUILDTYPE}/$@ $@

all: out/Makefile
	$(MAKE) -C out V=1 BUILDTYPE=$(BUILDTYPE) -j4
	-ln -fs out/${BUILDTYPE}/monitoring-agent monitoring-agent
	$(MAKE) $(sig_files) $(zip_files)

out/Release/monitoring-agent: all

out/Makefile:
	./configure

clean:
	rm -rf out

distclean:
	rm -rf out

VERSION=$(shell git describe)
TARNAME=virgo-$(VERSION)

test: tests
tests: all
	python tools/build.py test

test_endpoint:
	python tools/build.py test_endpoint

install: all
	install -d ${BINDIR}
	install -d ${ETCDIR}
	install -d ${SHAREDIR}
	install out/${BUILDTYPE}/monitoring-agent ${BINDIR}
	install out/${BUILDTYPE}/monitoring.zip ${SHAREDIR}
	install out/${BUILDTYPE}/monitoring-test.zip ${SHAREDIR}
	install -m 600 pkg/monitoring/rackspace-monitoring-agent.cfg ${ETCDIR}

dist:
	git archive --format=tar --prefix=$(TARNAME)/ HEAD | tar xf -
	tar -cf $(TARNAME).tar $(TARNAME)
	rm -rf $(TARNAME)
	gzip -f -9 $(TARNAME).tar

update:
	git submodule foreach git fetch && git submodule update --init --recursive

.PHONY: clean dist distclean all test tests endpoint-tests
