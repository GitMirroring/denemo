# This file is *NOT* part of MXE.
# See index.html for further information.
PKG             := denemo
$(PKG)_IGNORE   :=
$(PKG)_VERSION  := 2.6.52
$(PKG)_CHECKSUM := 01701c82fbd6c8a3a3b46480b2ea87c67f03065d78a86b28971595cba3658564
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
        --enable-guile_3_0 \
        --enable-portmidi \
        --disable-atril \
        --enable-evince \
        --enable-portaudio \
        --disable-rubberband \
        --disable-nls \
        PORTMIDI_LIBS="-lportmidi -lwinmm" \
        CPPFLAGS='-I$(PREFIX)/$(TARGET)/include -DSCM_STATIC_BUILD' \
        LDFLAGS='-L$(PREFIX)/$(TARGET)/lib' \
        GUILE_LIBS='$(PREFIX)/$(TARGET)/lib/libguile-3.0.a $(PREFIX)/$(TARGET)/lib/libgc.a -latomic_ops -ldl'
    #already there i guess cp '$(TOP_DIR)/packaging/denemo.ico' '$(1)/src/'
    '$(TARGET)-windres' '$(1)/src/denemo.rc' -o '$(1)/src/denemo_icon.o'
    echo 'denemo_LDADD += denemo_icon.o' >> '$(1)/src/Makefile'
    rm -rf '$(PREFIX)/$(TARGET)/share/denemo/actions'
    find '$(1)/actions' -xtype l -delete
    $(MAKE) -C '$(1)/' -j '$(JOBS)' AM_LDFLAGS="" install

    '$(TARGET)-gcc' \
        -W -Wall -ansi \
        '$(TOP_DIR)/src/lilypond-windows.c' -o '$(PREFIX)/$(TARGET)/bin/lilypond-windows.exe' 


endef

