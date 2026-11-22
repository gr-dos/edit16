# Build edit.exe (EDIT.EXE) for 16-bit real-mode MS-DOS with the Free
# Pascal i8086-msdos cross-compiler and its FreeVision units.
#   make                                  fetch the pinned compiler into
#                                         build/fpc8086, then build
#   make FPC8086_ROOT=$HOME/opt/fpc/3.2.2 use an unpacked copy of the
#                                         same release instead
#   make test                             run tests/run.sh under DOSBox-X
#   make perf                             size, memory and speed on an XT
#   make check-fv                         fv/editors.pas is 3.2.2 + the diff
#   make dist                             the release archive
#
# The compiler's default configuration is ignored (-n) so that a host
# fpc.cfg cannot add units or targets; everything is given here.
#
# FreeVision's code does not fit one 64 KB code segment, and the medium
# model leaves too little heap for several files, so this is the large
# model.  FreeVision's Editors unit is built from the patched copy in fv/
# (see fv/README.md) instead of the release's precompiled one: -Fu fv
# comes before the release's units, and its .ppu goes to build/obj.

FPC8086_ROOT ?= build/fpc8086
FPC_VERSION  := 3.2.2
MODEL        := large

PPC      := $(FPC8086_ROOT)/bin/ppcross8086
RTLUNITS := $(FPC8086_ROOT)/lib/fpc/$(FPC_VERSION)/units/msdos/8086-$(MODEL)
OBJDIR   := build/obj

VERSION := $(shell cat VERSION)

FPCFLAGS = -n -Tmsdos -Cp8086 -Wm$(MODEL) -O2 -Xs -XX -CX \
           -vewn -Fufv -Fifv -Fu'$(RTLUNITS)/*' -Fi$(OBJDIR) -FU$(OBJDIR)

SOURCES := $(wildcard *.pas) fv/editors.pas fv/platform.inc

edit.exe: $(SOURCES) $(OBJDIR)/version.inc $(PPC)
	$(PPC) $(FPCFLAGS) -o$@ edit16.pas

# VERSION compiled in as a Pascal string constant.
$(OBJDIR)/version.inc: VERSION
	mkdir -p $(OBJDIR)
	printf "const Version = '%s';\n" "$(VERSION)" > $@

# The pinned compiler (scripts/fetch-fpc8086). An FPC8086_ROOT given on
# the command line must already be unpacked.
ifeq ($(FPC8086_ROOT),build/fpc8086)
$(PPC): build/fpc8086/.tar-sha256
build/fpc8086/.tar-sha256: scripts/fetch-fpc8086
	sh scripts/fetch-fpc8086 build/fpc8086
	touch $@
endif

test: edit.exe
	sh tests/run.sh $(CURDIR)/edit.exe

# EXE size, memory and speed on an emulated 4.77 MHz XT (see the script)
perf: edit.exe
	sh tests/perf.sh $(CURDIR)/edit.exe

# fv/editors.pas must stay the 3.2.2 release's file plus
# fv/editors.diff, and nothing else.
check-fv: scripts/check-fv
	sh scripts/check-fv

# The release archive: the program, its GR-DOS help topic (the path
# gr-dos/gr-dos#90 proposes), and the notices: edit16's (MIT), and
# FreeVision's (the GNU Library GPL in COPYING.fv, with the linking
# exception in LICENSE.fv).
DIST = build/edit16-$(VERSION).zip

dist: $(DIST)

$(DIST): edit.exe help/topics/EDIT.txt README.md LICENSE VERSION fv/COPYING.FPC fv/COPYING
	rm -rf build/dist $@
	mkdir -p build/dist/help/topics
	cp edit.exe README.md LICENSE VERSION build/dist/
	cp help/topics/EDIT.txt build/dist/help/topics/
	cp fv/COPYING.FPC build/dist/LICENSE.fv
	cp fv/COPYING build/dist/COPYING.fv
	cd build/dist && zip -q -X -r ../edit16-$(VERSION).zip .

clean:
	rm -rf $(OBJDIR) build/dist edit.exe *.o *.ppu *.map

.PHONY: test perf check-fv dist clean
