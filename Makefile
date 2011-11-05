BUILDTYPE ?= Release

all: out/Makefile
	tools/gyp_virgo -f make
	$(MAKE) -C out V=1 BUILDTYPE=$(BUILDTYPE)
	-ln -fs out/Release/monitoring-agent monitoring-agent

out/Release/monitoring-agent: all

out/Makefile: options.gypi virgo.gyp deps/uv/uv.gyp
	tools/gyp_virgo -f make

clean:
	rm -rf out

distclean:
	rm -rf out

VERSION=$(shell git describe)
TARNAME=virgo-$(VERSION)

dist:
	git archive --format=tar --prefix=$(TARNAME)/ HEAD | tar xf -
	tar -cf $(TARNAME).tar $(TARNAME)
	rm -rf $(TARNAME)
	gzip -f -9 $(TARNAME).tar

.PHONY: clean dist distclean all
