BUILDTYPE ?= Debug
DESTDIR ?=

all: out/Makefile
	$(MAKE) -C out BUILDTYPE=$(BUILDTYPE) -j4
#	openssl dgst -sha256 -sign tests/ca/server.key.insecure ${PKG_NAME} > out/${BUILDTYPE}/${PKG_NAME}.sig
#	-ln -fs out/${BUILDTYPE}/${PKG_NAME}.sig ${PKG_NAME}.sig

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

install: all
	install -d ${BINDIR}
	install -d ${ETCDIR}
	install -d ${SHAREDIR}
	install out/${BUILDTYPE}/virgo ${BINDIR}/${PKG_NAME}
	install out/${BUILDTYPE}/${BUNDLE_NAME}-bundle.zip ${SHAREDIR}/${BUNDLE_NAME}-${BUNDLE_VERSION}.zip
#	install out/${BUILDTYPE}/bundle-test.zip ${SHAREDIR}

dist:
	# -ln -fs out/${BUILDTYPE}/${PKG_NAME} ${PKG_NAME}
	./tools/git-archive-all/git-archive-all --prefix=${TARNAME}/ out/${TARNAME}.tar.gz
	tar xzf out/${TARNAME}.tar.gz -C out
	cp -f platform.gypi out/${TARNAME}/
	touch out/${TARNAME}/no_gen_platform_gypi
	make -C deps/luvit dist_build
	mv deps/luvit/luvit.gyp.dist out/${TARNAME}/deps/luvit/luvit.gyp
	cp -f lib/virgo_exports.c out/${TARNAME}/lib/virgo_exports.c
	cd out && tar -cf ${TARNAME}.tar ${TARNAME}
	gzip -f -9 out/${TARNAME}.tar > out/${TARNAME}.tar.gz


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
#	cp out/${TARNAME}.tar.gz $(rpmbuild_dir)/SOURCES/
#	mv out/${TARNAME} $(rpmbuild_dir)/BUILD/
	cp -rf ${BUNDLE_DIR} $(rpmbuild_dir)/BUILD/
	mv out/${TARNAME}.tar.gz $(rpmbuild_dir)/SOURCES/
	cp out/${PKG_NAME}.spec $(rpmbuild_dir)/SPECS/
	rpmbuild --define '_topdir $(PWD)/$(rpmbuild_dir)' -ba out/${PKG_NAME}.spec

rpm-sign:
	-mv ~/.rpmmacros ~/.rpmmacros.bak
	ln -s $(PWD)/pkg/rpm/rpm_macros_gpg ~/.rpmmacros
	find $(rpmbuild_dir)/ -type f -name *.rpm -exec pkg/rpm/rpm-sign.exp {} \;
	rm ~/.rpmmacros
	-mv ~/.rpmmacros.bak ~/.rpmmacros

#######################
### Debian
export NAME := ${SHORT_DESCRIPTION} Package Repo ${DOCUMENTATION_LINK}
export EMAIL := ${EMAIL}
echo:
	echo "$(NAME)"
	echo "$(EMAIL)"

debbuild_dir = out/debbuild

$(debbuild_dir):
	mkdir -p $@

deb: all dist $(debbuild_dir)
	cp out/${TARNAME}.tar.gz $(debbuild_dir)
	rm -rf $(debbuild_dir)/${TARNAME} && mkdir $(debbuild_dir)/${TARNAME}
	tar zxf out/${TARNAME}.tar.gz --strip-components=1 -C $(debbuild_dir)/${TARNAME}
	cp -rf out/debian $(debbuild_dir)/${TARNAME}/debian
	cp -rf ${BUNDLE_DIR} $(debbuild_dir)
	# cd $(debbuild_dir)/${TARNAME} #&& dch -v ${VERSION} 'Release of ${PKG_NAME-VERSION}'
	cd $(debbuild_dir)/${TARNAME} && dpkg-buildpackage

deb-sign:
	@echo noop

PKG_TYPE=$(shell python ./tools/pkgutils.py)
pkg:
	python ./tools/version.py > out/VERSION
	[ "$(PKG_TYPE)" = "None" ] || $(MAKE) $(PKG_TYPE)

pkg-sign:
	[ "$(PKG_TYPE)" = "None" ] || make $(PKG_TYPE)-sign

update:
	git submodule foreach git fetch && git submodule update --init --recursive


.PHONY: clean dist distclean all test tests endpoint-tests rpm $(spec_file_built) deb pkg rpm-sign pkg-sign

# this Makefile is generated by make via gyp :(
# it can't be made sooner because gyp needs to expand bundled variables first
# variables it contains are only used post compile, ie in making pkgs
-include out/include.mk
