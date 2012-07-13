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

spec_file_name = rackspace-monitoring-agent.spec
spec_file_dir = pkg/monitoring/rpm
spec_file_built = out/$(spec_file_name)
spec_file_in = $(spec_file_dir)/$(spec_file_name).in

$(spec_file_built): $(spec_file_in)
	sed -e 's/@@VERSION@@/$(RPM_VERSION)/g' \
	    -e 's/@@RELEASE@@/$(RPM_RELEASE)/g' \
	    -e 's/@@TARNAME@@/$(TARNAME)/g' < $< > $@

dist_build:
	sed -e 's/VIRGO_VERSION=".*/VIRGO_VERSION=\"${VERSION}\"'\'',/' < monitoring-agent.gyp > monitoring-agent.gyp.dist

dist: dist_build $(spec_file_built)
	./tools/git-archive-all/git-archive-all --prefix=virgo-$(VERSION)/ virgo-$(VERSION).tar.gz
	tar xzf virgo-$(VERSION).tar.gz
	make -C deps/luvit dist_build
	cp $(spec_file_built) $(TARNAME)/$(spec_file_dir)
	mv monitoring-agent.gyp.dist $(TARNAME)/monitoring-agent.gyp
	mv deps/luvit/luvit.gyp.dist $(TARNAME)/deps/luvit/luvit.gyp
	mv deps/luvit/Makefile.dist $(TARNAME)/deps/luvit/Makefile
	tar -cf $(TARNAME).tar $(TARNAME)
	rm -rf $(TARNAME)
	gzip -f -9 $(TARNAME).tar

rpmbuild_dir = out/rpmbuild
rpmbuild_dirs = $(rpmbuild_dir)/SPECS \
                $(rpmbuild_dir)/SOURCES \
                $(rpmbuild_dir)/RPMS \
                $(rpmbuild_dir)/BUILD \
                $(rpmbuild_dir)/SRPMS

$(rpmbuild_dirs):
	mkdir -p $@

rpm: dist $(rpmbuild_dirs)
	cp $(spec_file_built) $(rpmbuild_dir)/SPECS/
	cp $(TARNAME).tar.gz $(rpmbuild_dir)/SOURCES/
	rpmbuild --define '_topdir $(PWD)/$(rpmbuild_dir)' -ba $(spec_file_built)

update:
	git submodule foreach git fetch && git submodule update --init --recursive


.PHONY: clean dist distclean all test tests endpoint-tests rpm $(spec_file_built)
