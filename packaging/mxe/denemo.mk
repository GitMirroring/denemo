# This file is *NOT* part of MXE.
# See index.html for further information.
PKG             := denemo
$(PKG)_IGNORE   :=
$(PKG)_VERSION  := 2.6.52
$(PKG)_CHECKSUM := 
$(PKG)_SUBDIR   := denemo-$($(PKG)_VERSION)
$(PKG)_FILE     := denemo-$($(PKG)_VERSION).tar.gz
$(PKG)_URL      := https://denemo.org/~jjbenham/denemo-snapshot/$($(PKG)_FILE)
$(PKG)_DEPS     := gcc gtk3 gtksourceview aubio portaudio librsvg libgcrypt portmidi libsndfile evince rubberband fluidsynth guile

#TODO portmidi rubnerband path
#TODO make tests for gtksourceview
#TODO upgrade aubio
#z%TODO write test for aubio
#TODO write test for evince 
define $(PKG)_UPDATE
    $(WGET) -q -O- 'https://denemo.org/~jjbenham/denemo-snapshot/' | \
    grep 'denemo-' | \
   $(SED) -n 's,.*denemo-\([0-9][^>]*\)\.tar.*,\1,p' | \
sort | \
tail -1
endef
define $(PKG)_BUILD
    cd '$(1)/' && ./configure \
        $(MXE_CONFIGURE_OPTS) \
        --disable-binreloc \
        --enable-debug \
        --enable-guile_2_2 \
        --enable-portmidi \
        --disable-atril \
        --enable-evince \
        --enable-portaudio \
        --disable-rubberband \
        --disable-nls \
        PORTMIDI_LIBS="-lportmidi -lwinmm" \
	CPPFLAGS='-I$(PREFIX)/$(TARGET)/include' \
        LDFLAGS='-L$(PREFIX)/$(TARGET)/lib' \
        CFLAGS=""
    $(MAKE) -C '$(1)/' -j '$(JOBS)' AM_LDFLAGS=""  install

    '$(TARGET)-gcc' \
        -W -Wall -ansi \
        '$(TOP_DIR)/src/lilypond-windows.c' -o '$(PREFIX)/$(TARGET)/bin/lilypond-windows.exe' 


endef

