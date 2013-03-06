BUILDTYPE ?= Debug
BINARY_NAME=virgo
DESTDIR ?=
BINDIR = ${DESTDIR}/usr/bin
SHAREDIR = ${DESTDIR}/usr/share/rackspace-monitoring-agent
ETCDIR = ${DESTDIR}/etc
VERSION=$(shell git describe --tags --always)
TARNAME=virgo-$(VERSION)
PKG_FULL_VERSION = $(shell python tools/version.py)
PKG_VERSION = $(shell python tools/version.py tag)
PKG_RELEASE = $(shell python tools/version.py release)

all: out/Makefile
	$(MAKE) -C out BUILDTYPE=$(BUILDTYPE) -j4
	-ln -fs out/${BUILDTYPE}/$(BINARY_NAME) $(BINARY_NAME)
#	openssl dgst -sha256 -sign tests/ca/server.key.insecure $(BINARY_NAME) > out/${BUILDTYPE}/$(BINARY_NAME).sig
#	-ln -fs out/${BUILDTYPE}/$(BINARY_NAME).sig $(BINARY_NAME).sig

out/Release/monitoring-agent: all

out/Makefile:
	./configure

clean:
	rm -rf out

distclean:
	rm -rf out

pep8:
	python tools/pep8.py --exclude=deps,gyp,contrib,pep8.py --ignore=E126,E501,E128,E127 . configure

test: tests
tests: all
	python tools/build.py test
	$(MAKE) pep8

crash: all
	python tools/build.py crash

test_endpoint:
	python tools/build.py test_endpoint

install: all
	install -d ${BINDIR}
	install -d ${ETCDIR}
	install -d ${SHAREDIR}
	install out/${BUILDTYPE}/$(BINARY_NAME) ${BINDIR}/$(BINARY_NAME)
	install out/${BUILDTYPE}/bundle.zip ${SHAREDIR}
#	install out/${BUILDTYPE}/bundle-test.zip ${SHAREDIR}

spec_file_name = rackspace-monitoring-agent.spec
spec_file_dir = pkg/rpm
spec_file_built = out/$(spec_file_name)
spec_file_in = $(spec_file_dir)/$(spec_file_name).in

$(spec_file_built): $(spec_file_in)
	sed -e 's/@@VERSION@@/$(PKG_VERSION)/g' \
	    -e 's/@@RELEASE@@/$(PKG_RELEASE)/g' \
	    -e 's/@@TARNAME@@/$(TARNAME)/g' < $< > $@

dist_build:
	sed -e "s/'BUNDLE_VERSION':.*/'BUNDLE_VERSION': '${VERSION}',/" \
	      < virgo.gyp > virgo.gyp.dist
	sed -e 's/VIRGO_VERSION=".*/VIRGO_VERSION=\"${VERSION}\"'\'',/' \
	      < lib/virgolib.gyp > lib/virgolib.gyp.dist
	sed -e 's/^VERSION=.*/VERSION=${VERSION}/' < Makefile > Makefile.dist

dist: dist_build $(spec_file_built)
	./tools/git-archive-all/git-archive-all --prefix=virgo-$(VERSION)/ virgo-$(VERSION).tar.gz
	tar xzf virgo-$(VERSION).tar.gz
	make -C deps/luvit dist_build
	cp $(spec_file_built) $(TARNAME)/$(spec_file_dir)
	mv lib/virgolib.gyp.dist $(TARNAME)/lib/virgolib.gyp
	mv virgo.gyp.dist $(TARNAME)/virgo.gyp
	mv deps/luvit/luvit.gyp.dist $(TARNAME)/deps/luvit/luvit.gyp
	mv deps/luvit/Makefile.dist $(TARNAME)/deps/luvit/Makefile
	mv Makefile.dist $(TARNAME)/Makefile
	tar -cf $(TARNAME).tar $(TARNAME)
	rm -rf $(TARNAME)
	gzip -f -9 $(TARNAME).tar

#######################
### RPM

rpmbuild_dir = out/rpmbuild
rpmbuild_dirs = $(rpmbuild_dir)/SPECS \
                $(rpmbuild_dir)/SOURCES \
                $(rpmbuild_dir)/RPMS \
                $(rpmbuild_dir)/BUILD \
                $(rpmbuild_dir)/SRPMS

$(rpmbuild_dirs):
	mkdir -p $@

rpm: all dist $(rpmbuild_dirs)
	cp $(spec_file_built) $(rpmbuild_dir)/SPECS/
	cp $(TARNAME).tar.gz $(rpmbuild_dir)/SOURCES/
	rpmbuild --define '_topdir $(PWD)/$(rpmbuild_dir)' -ba $(spec_file_built)

rpm-sign:
	-mv ~/.rpmmacros ~/.rpmmacros.bak
	ln -s $(PWD)/pkg/rpm/rpm_macros_gpg ~/.rpmmacros
	find $(rpmbuild_dir)/ -type f -name *.rpm -exec pkg/rpm/rpm-sign.exp {} \;
	rm ~/.rpmmacros
	-mv ~/.rpmmacros.bak ~/.rpmmacros

#######################
### Debian
export NAME := Rackspace Cloud Monitoring Agent Package Repo (http://www.rackspace.com/cloud/cloud_hosting_products/monitoring/)
export EMAIL := monitoring@rackspace.com

echo:
	echo "$(NAME)"
	echo "$(EMAIL)"

debbuild_dir = out/debbuild

$(debbuild_dir):
	mkdir -p $@

deb: all dist $(debbuild_dir)
	cp $(TARNAME).tar.gz $(debbuild_dir)
	rm -rf $(debbuild_dir)/rackspace-monitoring-agent && mkdir -p $(debbuild_dir)/rackspace-monitoring-agent
	tar zxf $(TARNAME).tar.gz --strip-components=1 -C $(debbuild_dir)/rackspace-monitoring-agent
	cd $(debbuild_dir)/rackspace-monitoring-agent && dch -v ${PKG_FULL_VERSION} 'Release of ${VERSION}'
	cd $(debbuild_dir)/rackspace-monitoring-agent && dpkg-buildpackage

deb-sign:
	@echo noop

PKG_TYPE=$(shell python ./tools/pkgutils.py)
pkg:
	python ./tools/version.py > out/VERSION
	[ "$(PKG_TYPE)" == "None" ] || $(MAKE) $(PKG_TYPE)

pkg-sign:
	[ "$(PKG_TYPE)" == "None" ] || make $(PKG_TYPE)-sign

update:
	git submodule foreach git fetch && git submodule update --init --recursive


.PHONY: clean dist distclean all test tests endpoint-tests rpm $(spec_file_built) deb pkg rpm-sign pkg-sign
