# GoldenPod makefile

VERSION=0.7

ifndef prefix
# This little trick ensures that make install will succeed both for a local
# user and for root. It will also succeed for distro installs as long as
# prefix is set by the builder.
prefix=$(shell perl -e 'if($$< == 0 or $$> == 0) { print "/usr" } else { print "$$ENV{HOME}/.local"}')
endif

BINDIR ?= $(prefix)/bin
DATADIR ?= $(prefix)/share

# Install goldenpod
install:
	mkdir -p "$(BINDIR)"
	cp goldenpod "$(BINDIR)"
	mkdir -p "$(DATADIR)"
	cp gpconf "$(BINDIR)"
	cp -r art "$(DATADIR)/goldenpod"
	chmod 755 "$(BINDIR)/goldenpod" "$(BINDIR)/gpconf"
# Unisntall an installed goldenpod
uninstall:
	rm -f "$(BINDIR)/goldenpod" "$(BINDIR)/gpconf"
	rm -rf "$(DATADIR)/goldenpod"
# Clean up the tree
clean:
	rm -f `find|egrep '~$$'`
	rm -f goldenpod-$(VERSION).tar.bz2
	rm -rf goldenpod-$(VERSION)
	rm -f goldenpod.1
# Verify syntax
test:
	@perl -c goldenpod
	@perl -c gpconf
	@perl -c devel-tools/SetVersion
# Create a manpage from the POD
man:
	pod2man --name "goldenpod" --center "" --release "GoldenPod $(VERSION)" ./goldenpod ./goldenpod.1
# Create the tarball
distrib: clean test man
	mkdir -p goldenpod-$(VERSION)
	cp -r ./`ls|grep -v goldenpod-$(VERSION)` ./goldenpod-$(VERSION)
	rm -rf `find goldenpod-$(VERSION) -name \\.git`
	tar -jcvf goldenpod-$(VERSION).tar.bz2 ./goldenpod-$(VERSION)
	rm -rf goldenpod-$(VERSION)
