# Use this Makefile only with GNU make
# (GNU make is the standard make on Linux,
# on Windows it comes with FPC or Cygwin or MinGW,
# on FreeBSD it is gmake).

# ------------------------------------------------------------
# Various targets.

# default: make sure that various files are up-to-date, and show info
default: info
	$(MAKE) -C source/
	$(MAKE) -C data/items/models/
	$(MAKE) -C data/items/images/
	$(MAKE) -C data/items/equipped/
	$(MAKE) -C data/levels/

VERSION := $(shell ./castle --version)

info:
	@echo 'Version is '$(VERSION)

# ------------------------------------------------------------
# Building targets.
#
# You may wish to call target `clean' before
# calling build targets. This will make sure that everything is
# compiled with appropriate options (suitable for release or debugging,
# and that GLWindow unit uses proper backend).
#
# Call make with DEBUG=t to get debug build, otherwise release build
# will be done.

ifdef DEBUG
FPC_UNIX_OPTIONS := -dDEBUG
FPC_WIN32_OPTIONS := -dDEBUG
else
FPC_UNIX_OPTIONS := -dRELEASE -dGLWINDOW_XLIB
FPC_WIN32_OPTIONS := -dRELEASE
endif

build-unix:
	cd source; \
	  fpc $(FPC_UNIX_OPTIONS) @kambi.cfg castle.dpr; \
	  mv castle ../

build-win32:
	cd source; \
	  fpc $(FPC_WIN32_OPTIONS) @kambi.cfg castle.dpr; \
	  mv castle.exe ../

# ------------------------------------------------------------
# Cleaning targets.

clean:
	find . -type f '(' -iname '*.ow'  -or -iname '*.ppw' -or -iname '*.aw' -or \
	                   -iname '*.o'   -or -iname '*.ppu' -or -iname '*.a' -or \
	                   -iname '*.dcu' -or -iname '*.dpu' -or \
			   -iname '*~' -or \
	                   -iname '*.~???' -or \
			   -iname '*.blend1' ')' -print \
	     | xargs rm -f
	rm -f castle-?.?.?.tar.gz
	$(MAKE) -C source/ clean

# Remove private files that Michalis keeps inside his castle/trunk/,
# but he doesn't want to upload them for PGD compo.
#
# These things are *not* automatically generated (automatically generated
# stuff is removed always by `clean'). So this target is supposed to be
# used only by `make dist', it does it inside temporary copy of castle/trunk/.
clean_private:
	find . -type d '(' -iname '.svn' ')' -print \
	     | xargs rm -Rf

# ------------------------------------------------------------
# Dist making.

TMP_DIST_PATH := /tmp/castle_dist_tmp/

# Uncomment to get bzip2 packed dist
#BZIP2 := t

ifdef BZIP2
DIST_EXTENSION := bz2
DIST_TAR_FILTER := --bzip2
else
DIST_EXTENSION := gz
DIST_TAR_FILTER := --gzip
endif

# Make distribution tar.gz to upload for PGD competition.
# For now, this target is not supposed to be run by anyone
# else than me (Michalis), because it depends on some private
# scripts of mine and directory layout
# (in particular, I include here my general units, that are
# packed into tar.gz using my private script).
#
# Before doing this target, remember to
# - make sure Version in castleplay.pas is correct
# - recompile castle for Linux and Windows
dist:
# Start with empty $(TMP_DIST_PATH)
	rm -Rf $(TMP_DIST_PATH)
	mkdir -p $(TMP_DIST_PATH)
# Copy and clean castle/trunk/ directory
	cp -R ../trunk/ $(TMP_DIST_PATH)
	mv $(TMP_DIST_PATH)trunk/ $(TMP_DIST_PATH)castle
	make -C $(TMP_DIST_PATH)castle/ clean clean_private
	areFilenamesLower -i Makefile $(TMP_DIST_PATH)castle/data/
# Add libpng and zlib for Windows
	cp -f /win/mojewww/camelot/private/win32_libpng_and_zlib/* $(TMP_DIST_PATH)castle/
# Setup right permissions of things (in castle/trunk/ and libpng/zlib)
# (because they are kept on FAT filesystem)
	find $(TMP_DIST_PATH) -type f -and -exec chmod 644 '{}' ';'
	find $(TMP_DIST_PATH) -type d -and -exec chmod 755 '{}' ';'
	find $(TMP_DIST_PATH) -type f -and -iname '*.sh' -and -exec chmod 755 '{}' ';'
	chmod 755 $(TMP_DIST_PATH)castle/castle
# Copy and clean general units sources
	cd /win/mojewww/camelot/private/update_archives/; ./update_pascal_src.sh units
	cp /win/mojewww/camelot/src/pascal/units-src.tar.gz $(TMP_DIST_PATH)castle/source/
	cd $(TMP_DIST_PATH)castle/source/; tar xzf units-src.tar.gz
	rm -f $(TMP_DIST_PATH)castle/source/units-src.tar.gz
	mv $(TMP_DIST_PATH)castle/source/COPYING $(TMP_DIST_PATH)castle/COPYING
# Pack things
	cd $(TMP_DIST_PATH); tar -c $(DIST_TAR_FILTER) -f \
	  castle-$(VERSION).tar.$(DIST_EXTENSION) castle/
	mv $(TMP_DIST_PATH)castle-$(VERSION).tar.$(DIST_EXTENSION) .

# ----------------------------------------
# Set SVN tag.

svntag:
	svn copy file:///home/michal/svn/kambi-svn-repos/castle/trunk/ \
	         file:///home/michal/svn/kambi-svn-repos/castle/tags/$(VERSION) \
	  -m "Tagging the $(VERSION) version of 'The Castle'."

# eof ------------------------------------------------------------