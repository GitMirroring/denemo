#!/bin/bash
# Launcher wrapper - sets up environment for the bundled GTK app.
BUNDLE="$(cd "$(dirname "$0")/../.."; pwd)"
RESOURCES="${BUNDLE}/Contents/Resources"
LIBS="${BUNDLE}/Contents/libs"

export DYLD_LIBRARY_PATH="${LIBS}:${DYLD_LIBRARY_PATH:-}"
export XDG_DATA_DIRS="${RESOURCES}/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export GSETTINGS_SCHEMA_DIR="${RESOURCES}/share/glib-2.0/schemas:${GSETTINGS_SCHEMA_DIR:-}"
export GDK_PIXBUF_MODULE_FILE="${RESOURCES}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"
export GTK_PATH="${RESOURCES}/lib/gtk-3.0"
export PANGO_LIBDIR="${LIBS}"
export FONTCONFIG_PATH="${RESOURCES}/etc/fonts"

# ── Guile ─────────────────────────────────────────────────────────────────────
# Guile needs its Scheme boot files (ice-9/boot-9, etc.) and compiled cache.
# Without these it aborts immediately with "Unable to find file ice-9/boot-9".
# We ship the guile share tree inside Resources/share/guile and the compiled
# .go files inside Resources/lib/guile/<ver>/ccache (copied by bundle script).
GUILE_VER="3.0"
export GUILE_LOAD_PATH="${RESOURCES}/share/guile/${GUILE_VER}:${RESOURCES}/share/guile/site/${GUILE_VER}"
export GUILE_LOAD_COMPILED_PATH="${RESOURCES}/lib/guile/${GUILE_VER}/ccache:${RESOURCES}/lib/guile/${GUILE_VER}/site-ccache"
export GUILE_SYSTEM_EXTENSIONS_PATH="${RESOURCES}/lib/guile/${GUILE_VER}/extensions"

# ── Denemo / LilyPond ────────────────────────────────────────────────────────
export LILYPOND_DATADIR="${RESOURCES}/share/lilypond"
export DENEMO_DATADIR="${RESOURCES}/share/denemo"
export PATH="${BUNDLE}/Contents/MacOS:${PATH}"

exec "${BUNDLE}/Contents/MacOS/denemo-bin" "$@"
