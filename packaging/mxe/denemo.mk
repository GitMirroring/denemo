# This file is *NOT* part of MXE.
# See index.html for further information.
PKG             := denemo
$(PKG)_IGNORE   :=
$(PKG)_VERSION  := 2.6.51
$(PKG)_CHECKSUM := e623b4061b3b6122b6db996e12d9df3324e140435d04ae55b4a6eec7f67cc6eb
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
        CFLAGS="-mwindows" 
    $(MAKE) -C '$(1)/' -j '$(JOBS)' AM_LDFLAGS="-mwindows"  install

    '$(TARGET)-gcc' \
        -W -Wall -ansi -mwindows \
        '$(TOP_DIR)/src/lilypond-windows.c' -o '$(PREFIX)/$(TARGET)/bin/lilypond-windows.exe' 


endef

