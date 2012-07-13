BUILDTYPE ?= Debug

DESTDIR ?=
BINDIR = ${DESTDIR}/usr/bin
SHAREDIR = ${DESTDIR}/usr/share/rackspace-monitoring-agent
ETCDIR = ${DESTDIR}/etc

zip_files = monitoring.zip monitoring-test.zip
sig_files = $(zip_files:%.zip=%.zip.sig)

spec_file = pkg/monitoring/rpm/rackspace-monitoring-agent.spec

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

VERSION=$(shell git describe --tags --always)
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
	install out/${BUILDTYPE}/monitoring-agent ${BINDIR}/monitoring-rackspace
	install out/${BUILDTYPE}/monitoring.zip ${SHAREDIR}
	install out/${BUILDTYPE}/monitoring-test.zip ${SHAREDIR}
	install -m 600 pkg/monitoring/rackspace-monitoring-agent.cfg ${ETCDIR}

# Generate versions for RPM without dashes from git describe
# make release 0 if tag matches exactly
RPM_VERLIST = $(filter-out dirty,$(subst -, ,$(VERSION))) 0
RPM_VERSION = $(word 1,$(RPM_VERLIST))
RPM_RELEASE = $(word 2,$(RPM_VERLIST))

$(spec_file): $(spec_file).in
	sed -e 's/@@VERSION@@/$(RPM_VERSION)/g' \
	    -e 's/@@RELEASE@@/$(RPM_RELEASE)/g' \
	    -e 's/@@TARNAME@@/$(TARNAME)/g' < $< > $@

dist_build:
	sed -e 's/VIRGO_VERSION=".*/VIRGO_VERSION=\"${VERSION}\"'\'',/' < monitoring-agent.gyp > monitoring-agent.gyp.dist

dist: dist_build $(spec_file)
	./tools/git-archive-all/git-archive-all --prefix=virgo-$(VERSION)/ virgo-$(VERSION).tar.gz
	tar xzf virgo-$(VERSION).tar.gz
	make -C deps/luvit dist_build
	cp $(spec_file) $(TARNAME)/$(spec_file)
	mv monitoring-agent.gyp.dist $(TARNAME)/monitoring-agent.gyp
	mv deps/luvit/luvit.gyp.dist $(TARNAME)/deps/luvit/luvit.gyp
	mv deps/luvit/Makefile.dist $(TARNAME)/deps/luvit/Makefile
	tar -cf $(TARNAME).tar $(TARNAME)
	rm -rf $(TARNAME)
	gzip -f -9 $(TARNAME).tar

rpm: dist
	mkdir -p rpmbuild/SPECS rpmbuild/SOURCES rpmbuild/RPMS rpmbuild/BUILD rpmbuild/SRPMS
	cp $(spec_file) rpmbuild/SPECS/
	cp $(TARNAME).tar.gz rpmbuild/SOURCES/
	rpmbuild --define '_topdir $(PWD)/rpmbuild' -ba $(spec_file)

update:
	git submodule foreach git fetch && git submodule update --init --recursive


.PHONY: clean dist distclean all test tests endpoint-tests rpm $(spec_file)
