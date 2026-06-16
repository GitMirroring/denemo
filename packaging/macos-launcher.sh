#!/bin/bash
# Resolve the bundle path robustly even if cwd doesn't exist
SCRIPT="$0"
# Resolve symlinks
while [ -L "$SCRIPT" ]; do
    SCRIPT="$(readlink "$SCRIPT")"
done
BUNDLE="$(cd "$(dirname "$SCRIPT")/../.." 2>/dev/null && pwd)"
if [ -z "$BUNDLE" ]; then
    # Fallback: derive from script path directly
    BUNDLE="${0%/Contents/MacOS/*}"
fi
RESOURCES="${BUNDLE}/Contents/Resources"
LIBS="${BUNDLE}/Contents/libs"
# ── Dylibs ────────────────────────────────────────────────────────────────────
export DYLD_LIBRARY_PATH="${LIBS}:${DYLD_LIBRARY_PATH:-}"

# ── GTK / GDK ─────────────────────────────────────────────────────────────────
export XDG_DATA_DIRS="${RESOURCES}/share:/usr/local/share:/usr/share"
export GSETTINGS_SCHEMA_DIR="${RESOURCES}/share/glib-2.0/schemas:${GSETTINGS_SCHEMA_DIR:-}"
export GDK_PIXBUF_MODULE_FILE="${RESOURCES}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"
export GTK_PATH="${RESOURCES}/lib/gtk-3.0"
export PANGO_LIBDIR="${LIBS}"

# ── Fontconfig ────────────────────────────────────────────────────────────────
export FONTCONFIG_PATH="${RESOURCES}/etc/fonts"
export FONTCONFIG_FILE="${RESOURCES}/etc/fonts/fonts.conf"
export FC_DEBUG=0

# ── Guile ─────────────────────────────────────────────────────────────────────
GUILE_VER="3.0"

# Detect LilyPond version dynamically
LILY_VER=$(ls "${RESOURCES}/share/lilypond/" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+' | sort -V | tail -1)
LILY_VER="${LILY_VER:-2.26.0}"

# GUILE_LOAD_PATH must include both Guile's own boot files AND LilyPond's
# Scheme files - without either, you get "Unable to find file ice-9/boot-9"
# or "Unable to find file lily/lily"
export GUILE_LOAD_PATH="\
${RESOURCES}/share/guile/${GUILE_VER}:\
${RESOURCES}/share/guile/site/${GUILE_VER}:\
${RESOURCES}/share/lilypond/${LILY_VER}/scm"
export GUILE_LOAD_COMPILED_PATH="\
${RESOURCES}/lib/guile/${GUILE_VER}/ccache:\
${RESOURCES}/lib/guile/${GUILE_VER}/site-ccache"
export GUILE_SYSTEM_EXTENSIONS_PATH="${RESOURCES}/lib/guile/${GUILE_VER}/extensions"

# ── Denemo ────────────────────────────────────────────────────────────────────
export DENEMO_DATADIR="${RESOURCES}/share"

# ── LilyPond ──────────────────────────────────────────────────────────────────
# LilyPond needs its own datadir for fonts and ly includes
export LILYPOND_DATADIR="${RESOURCES}/share/lilypond/${LILY_VER}"

# ── PATH - MacOS dir first so lilypond and gs are found before system copies ──
export PATH="${BUNDLE}/Contents/MacOS:${PATH}"

exec "${BUNDLE}/Contents/MacOS/denemo-bin" "$@"
