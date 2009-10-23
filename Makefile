# GoldenPod makefile

VERSION=$(shell ./goldenpod --version|perl -pi -e 's/^\D+//; chomp')

ifndef prefix
# This little trick ensures that make install will succeed both for a local
# user and for root. It will also succeed for distro installs as long as
# prefix is set by the builder.
prefix=$(shell perl -e 'if($$< == 0 or $$> == 0) { print "/usr" } else { print "$$ENV{HOME}/.local"}')

# Some additional magic here, what it does is set BINDIR to ~/bin IF we're not
# root AND ~/bin exists, if either of these checks fail, then it falls back to
# the standard $(prefix)/bin. This is also inside ifndef prefix, so if a
# prefix is supplied (for instance meaning this is a packaging), we won't run
# this at all
BINDIR ?= $(shell perl -e 'if(($$< > 0 && $$> > 0) and -e "$$ENV{HOME}/bin") { print "$$ENV{HOME}/bin";exit; } else { print "$(prefix)/bin"}')
endif

BINDIR ?= $(prefix)/bin
DATADIR ?= $(prefix)/share

DISTFILES = AUTHORS COPYING goldenpod INSTALL Makefile NEWS README TODO goldenpod.1

# Install goldenpod
install:
	mkdir -p "$(BINDIR)"
	cp goldenpod "$(BINDIR)"
	chmod 755 "$(BINDIR)/goldenpod"
	[ -e goldenpod.1 ] && mkdir -p "$(DATADIR)/man/man1" && cp goldenpod.1 "$(DATADIR)/man/man1" || true
localinstall:
	mkdir -p "$(BINDIR)"
	ln -sf $(shell pwd)/goldenpod $(BINDIR)/
	[ -e goldenpod.1 ] && mkdir -p "$(DATADIR)/man/man1" && ln -sf $(shell pwd)/goldenpod.1 "$(DATADIR)/man/man1" || true
# Uninstall an installed goldenpod
uninstall:
	rm -f "$(BINDIR)/goldenpod" "$(BINDIR)/gpconf" "$(DATADIR)/man/man1/goldenpod.1"
	rm -rf "$(DATADIR)/goldenpod"
# Clean up the tree
clean:
	rm -f `find|egrep '~$$'`
	rm -f goldenpod-*.tar.bz2
	rm -rf goldenpod-$(VERSION)
	rm -f goldenpod.1
# Verify syntax
test:
	@perl -c goldenpod
# Create a manpage from the POD
man:
	pod2man --name "goldenpod" --center "" --release "GoldenPod $(VERSION)" ./goldenpod ./goldenpod.1
# Create the tarball
distrib: clean test man
	mkdir -p goldenpod-$(VERSION)
	cp $(DISTFILES) ./goldenpod-$(VERSION)
	tar -jcvf goldenpod-$(VERSION).tar.bz2 ./goldenpod-$(VERSION)
	rm -rf goldenpod-$(VERSION)
	rm -f goldenpod.1
