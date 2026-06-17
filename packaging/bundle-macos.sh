#!/bin/bash
# packaging/bundle-macos.sh
# Creates a self-contained Denemo.app bundle and DMG for macOS.
# Run after `make install` with HOMEBREW_PREFIX set (default: /opt/homebrew).
#
# Usage:
#   ./packaging/bundle-macos.sh [--prefix /opt/homebrew] [--version 2.6]
#
# Requirements (all available via Homebrew):
#   brew install dylibbundler create-dmg

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────

HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/opt/homebrew}"
DENEMO_VERSION="${DENEMO_VERSION:-$(grep AC_INIT configure.ac | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)}"
DENEMO_VERSION="${DENEMO_VERSION:-unknown}"

BINARY="${HOMEBREW_PREFIX}/bin/denemo"
SHARE_DIR="${HOMEBREW_PREFIX}/share/denemo"
LOCALE_DIR="${HOMEBREW_PREFIX}/share/locale"
APP_NAME="Denemo"
APP_BUNDLE="${APP_NAME}.app"
STAGING_DIR="$(pwd)/macos_staging"
APP_DIR="${STAGING_DIR}/${APP_BUNDLE}"
DMG_NAME="Denemo-${DENEMO_VERSION}-macOS.dmg"
SCRIPT_DIR="$(cd "$(dirname "$0")"; pwd)"

# ── Sanity checks ─────────────────────────────────────────────────────────────

if [ ! -f "${BINARY}" ]; then
    echo "ERROR: denemo binary not found at ${BINARY}" >&2
    echo "  Run 'make install' first." >&2
    exit 1
fi

for tool in dylibbundler create-dmg; do
    if ! command -v "$tool" > /dev/null 2>&1; then
        echo "ERROR: '$tool' not found." >&2
        echo "  brew install dylibbundler create-dmg" >&2
        exit 1
    fi
done

echo "Bundling Denemo ${DENEMO_VERSION}..."
echo "  Binary:  ${BINARY}"
echo "  Data:    ${SHARE_DIR}"
echo "  Output:  ${APP_DIR}"

# ── 1. Create .app skeleton ───────────────────────────────────────────────────

rm -rf "${STAGING_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"
mkdir -p "${APP_DIR}/Contents/libs"

# ── 2. Copy Info.plist ────────────────────────────────────────────────────────

cat > "${APP_DIR}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>Denemo</string>
  <key>CFBundleExecutable</key>
  <string>denemo</string>
  <key>CFBundleIconFile</key>
  <string>denemo.icns</string>
  <key>CFBundleIdentifier</key>
  <string>org.gnu.denemo</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Denemo</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${DENEMO_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${DENEMO_VERSION}</string>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeExtensions</key>
      <array>
        <string>denemo</string>
      </array>
      <key>CFBundleTypeName</key>
      <string>Denemo Score</string>
      <key>CFBundleTypeRole</key>
      <string>Editor</string>
    </dict>
  </array>
  <key>LSMinimumSystemVersion</key>
  <string>12.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2024 Denemo contributors. Licensed under the GNU GPL.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF
# ── 3. Copy binary ────────────────────────────────────────────────────────────
cp "${BINARY}" "${APP_DIR}/Contents/MacOS/denemo"
chmod +x "${APP_DIR}/Contents/MacOS/denemo"
# ── 4. Create icon ────────────────────────────────────────────────────────────
# Convert the installed PNG to .icns using macOS sips + iconutil.
# Falls back gracefully if the PNG is missing.
# Source icon from the checked-out repo
SRCDIR="$(cd "$(dirname "$0")/.." && pwd)"
PNG_ICON="${SRCDIR}/pixmaps/org.denemo.Denemo.png"

if [ ! -f "${PNG_ICON}" ]; then
    PNG_ICON="${SRCDIR}/pixmaps/denemo128x128.png"
fi

ICNS_OUT="${APP_DIR}/Contents/Resources/denemo.icns"
if [ -f "${PNG_ICON}" ]; then
    echo "Creating .icns from ${PNG_ICON}..."
    ICONSET_DIR="$(mktemp -d)/denemo.iconset"
    mkdir -p "${ICONSET_DIR}"
    for size in 16 32 64 128; do
        sips -z ${size} ${size} "${PNG_ICON}" \
            --out "${ICONSET_DIR}/icon_${size}x${size}.png" > /dev/null
        double=$((size * 2))
        sips -z ${double} ${double} "${PNG_ICON}" \
            --out "${ICONSET_DIR}/icon_${size}x${size}@2x.png" > /dev/null
    done
    # 128 is our max source size - don't upscale beyond that
    iconutil -c icns "${ICONSET_DIR}" -o "${ICNS_OUT}"
    rm -rf "$(dirname ${ICONSET_DIR})"
else
    echo "WARNING: No icon found, bundle will have no icon"
fi


# ── 5. Copy application data into Resources ───────────────────────────────────

echo "Copying application data..."
cp -R "${SHARE_DIR}" "${APP_DIR}/Contents/Resources/share"

# Copy locale files for installed languages
if [ -d "${LOCALE_DIR}" ]; then
    mkdir -p "${APP_DIR}/Contents/Resources/share/locale"
    # Only copy denemo translations, not all of Homebrew's locale
    find "${LOCALE_DIR}" -name "denemo.mo" | while read mo; do
        lang=$(echo "$mo" | sed "s|${LOCALE_DIR}/||" | cut -d/ -f1)
        mkdir -p "${APP_DIR}/Contents/Resources/share/locale/${lang}/LC_MESSAGES"
        cp "$mo" "${APP_DIR}/Contents/Resources/share/locale/${lang}/LC_MESSAGES/"
    done
fi
# -- 5b. Bundle LilyPond
echo "Bundling LilyPond..."
LILYPOND_BIN="${HOMEBREW_PREFIX}/bin/lilypond"
if [ -f "${LILYPOND_BIN}" ]; then
    # 1. Copy ARM64 lilypond into bundle
    cp "${LILYPOND_BIN}" "${APP_DIR}/Contents/MacOS/lilypond"

    # 2. Run dylibbundler on thin ARM64 binary
    dylibbundler -of -cd -b \
        -x "${APP_DIR}/Contents/MacOS/lilypond" \
        -d "${APP_DIR}/Contents/libs/" \
        -p "@executable_path/../libs/"

    # 3. Lipo into universal
    X86_LILYPOND="/usr/local/bin/lilypond"
    if [ -f "${X86_LILYPOND}" ]; then
        echo "  Creating universal LilyPond binary..."
        lipo -create "${APP_DIR}/Contents/MacOS/lilypond" "${X86_LILYPOND}" \
             -output "${APP_DIR}/Contents/MacOS/lilypond.universal"
        mv "${APP_DIR}/Contents/MacOS/lilypond.universal" \
           "${APP_DIR}/Contents/MacOS/lilypond"

        # 4. Patch /usr/local/opt/ rpaths from x86_64 slice
        echo "  Patching x86_64 rpaths..."
        otool -L "${APP_DIR}/Contents/MacOS/lilypond" \
            | grep '/usr/local/opt/' \
            | awk '{print $1}' > /tmp/lily_deps.txt
        while IFS= read -r dep; do
            libname=$(basename "$dep")
            if [ -f "${APP_DIR}/Contents/libs/${libname}" ]; then
                install_name_tool -change "$dep" \
                    "@executable_path/../libs/${libname}" \
                    "${APP_DIR}/Contents/MacOS/lilypond"
                echo "    patched: $dep"
            else
                echo "    MISSING: ${libname}"
            fi
        done < /tmp/lily_deps.txt
        rm -f /tmp/lily_deps.txt

        # 5. Create symlinks for versioned libs
        for lib in "${APP_DIR}/Contents/libs/"*.dylib; do
            base=$(basename "$lib")
            short=$(echo "$base" | sed -E 's/([a-zA-Z_-]+\.[0-9]+)\.[0-9]+\.[0-9]+\.dylib/\1.dylib/')
            if [ "$short" != "$base" ] && [ ! -f "${APP_DIR}/Contents/libs/${short}" ]; then
                ln -sf "$base" "${APP_DIR}/Contents/libs/${short}"
                echo "    symlink: ${short} -> ${base}"
            fi
        done

        # 6. Re-sign
        codesign --force --sign - "${APP_DIR}/Contents/MacOS/lilypond"
        echo "  LilyPond archs: $(lipo -info ${APP_DIR}/Contents/MacOS/lilypond)"
    else
        echo "  WARNING: No x86_64 LilyPond found, bundle will be ARM64 only"
    fi

    if [ -d "${HOMEBREW_PREFIX}/share/lilypond" ]; then
        mkdir -p "${APP_DIR}/Contents/Resources/share/lilypond"
        cp -R "${HOMEBREW_PREFIX}/share/lilypond/" \
              "${APP_DIR}/Contents/Resources/share/lilypond/"
        echo "  LilyPond share bundled"
    fi
    if [ -d "${HOMEBREW_PREFIX}/lib/lilypond" ]; then
        mkdir -p "${APP_DIR}/Contents/libs/lilypond"
        cp -R "${HOMEBREW_PREFIX}/lib/lilypond/" \
              "${APP_DIR}/Contents/libs/lilypond/"
        echo "  LilyPond libs bundled"
    fi
    echo "  LilyPond bundled: ${LILYPOND_BIN}"
else
    echo "  WARNING: lilypond not found at ${LILYPOND_BIN}"
fi
# Copy Guile's Scheme source and compiled boot files into the bundle.
# Without ice-9/boot-9 (and friends) Guile aborts before main() even runs.
RESOURCES="${APP_DIR}/Contents/Resources"

# Detect installed Guile version (handles 3.0, future 3.2, etc.)
GUILE_VER=$(ls "${HOMEBREW_PREFIX}/share/guile/" | grep -E '^[0-9]+\.[0-9]+$' | sort -V | tail -1)
echo "=== Bundling Guile ${GUILE_VER} ==="

# 1. Scheme source tree (ice-9/, srfi/, system/, …)
mkdir -p "${RESOURCES}/share/guile/${GUILE_VER}"
cp -R "${HOMEBREW_PREFIX}/share/guile/${GUILE_VER}/" \
      "${RESOURCES}/share/guile/${GUILE_VER}/"

# 2. Site directory (may be empty but must exist)
mkdir -p "${RESOURCES}/share/guile/site/${GUILE_VER}"
if [ -d "${HOMEBREW_PREFIX}/share/guile/site/${GUILE_VER}" ]; then
  cp -R "${HOMEBREW_PREFIX}/share/guile/site/${GUILE_VER}/" \
        "${RESOURCES}/share/guile/site/${GUILE_VER}/"
fi

# 3. Pre-compiled .go cache (speeds startup)
mkdir -p "${RESOURCES}/lib/guile/${GUILE_VER}/ccache"
if [ -d "${HOMEBREW_PREFIX}/lib/guile/${GUILE_VER}/ccache" ]; then
  cp -R "${HOMEBREW_PREFIX}/lib/guile/${GUILE_VER}/ccache/" \
        "${RESOURCES}/lib/guile/${GUILE_VER}/ccache/"
fi

# 4. Site compiled cache (usually empty; must exist for the env var to be valid)
mkdir -p "${RESOURCES}/lib/guile/${GUILE_VER}/site-ccache"
if [ -d "${HOMEBREW_PREFIX}/lib/guile/${GUILE_VER}/site-ccache" ]; then
  cp -R "${HOMEBREW_PREFIX}/lib/guile/${GUILE_VER}/site-ccache/" \
        "${RESOURCES}/lib/guile/${GUILE_VER}/site-ccache/"
fi

# 5. Extensions (.so plugins Guile loads at runtime)
mkdir -p "${RESOURCES}/lib/guile/${GUILE_VER}/extensions"
if [ -d "${HOMEBREW_PREFIX}/lib/guile/${GUILE_VER}/extensions" ]; then
  cp -R "${HOMEBREW_PREFIX}/lib/guile/${GUILE_VER}/extensions/" \
        "${RESOURCES}/lib/guile/${GUILE_VER}/extensions/"
fi

echo "=== Guile bundle contents ==="
du -sh "${RESOURCES}/share/guile/" 2>/dev/null
du -sh "${RESOURCES}/lib/guile/"   2>/dev/null

# ── Install launcher ─────────────────────────────────────────────────────────
# ── Install launcher ─────────────────────────────────────────────────────────
mv "${APP_DIR}/Contents/MacOS/denemo" \
   "${APP_DIR}/Contents/MacOS/denemo-bin"
cp "${SCRIPT_DIR}/macos-launcher.sh" "${APP_DIR}/Contents/MacOS/denemo"
chmod +x "${APP_DIR}/Contents/MacOS/denemo"
# ── 7. Bundle dylibs ──────────────────────────────────────────────────────────
# dylibbundler copies all non-system Homebrew dylibs into Contents/libs/
# and rewrites the binary's load paths to @executable_path/../libs/

echo "Bundling dylibs..."
dylibbundler \
    --bundle-deps \
    --create-dir \
    --dest-dir "${APP_DIR}/Contents/libs/" \
    --fix-file "${APP_DIR}/Contents/MacOS/denemo-bin" \
    --install-path "@executable_path/../libs/" \
    --overwrite-dir \
    --search-path "${HOMEBREW_PREFIX}/lib" \
    --search-path "/usr/local/lib" \
    --search-path "${HOMEBREW_PREFIX}/opt/guile/lib" \
    --search-path "${HOMEBREW_PREFIX}/opt/gtk+3/lib" \
    --search-path "${HOMEBREW_PREFIX}/opt/glib/lib" \
    --search-path "${HOMEBREW_PREFIX}/opt/pango/lib" \
    --search-path "${HOMEBREW_PREFIX}/opt/cairo/lib" \
    --search-path "${HOMEBREW_PREFIX}/opt/evince/lib" \
    2>&1 | grep -v "^$" || true

# ── Make bundled dylibs universal ────────────────────────────────────────────
echo "Making bundled dylibs universal..."
for lib in "${APP_DIR}/Contents/libs/"*.dylib; do
    libname=$(basename "$lib")
    # Check if already universal
    if lipo -info "$lib" 2>/dev/null | grep -q "x86_64"; then
        echo "  already universal: ${libname}"
        continue
    fi
    # Find x86_64 counterpart in /usr/local
    x86lib=""
    for searchdir in /usr/local/lib /usr/local/opt/*/lib; do
        if [ -f "${searchdir}/${libname}" ]; then
            x86lib="${searchdir}/${libname}"
            break
        fi
    done
    # Also search Cellar
    if [ -z "${x86lib}" ]; then
        x86lib=$(find /usr/local/Cellar -name "${libname}" \
                 -path "*/lib/*" 2>/dev/null | head -1)
    fi
    if [ -n "${x86lib}" ]; then
        if lipo -create "${lib}" "${x86lib}" \
                -output "${lib}.universal" 2>/dev/null; then
            mv "${lib}.universal" "${lib}"
            codesign --force --sign - "${lib}"
            echo "  universal: ${libname}"
        else
            echo "  lipo failed: ${libname}"
        fi
    else
        echo "  ARM64 only (no x86_64 found): ${libname}"
    fi
done
# ── 8. Bundle GDK pixbuf loaders ─────────────────────────────────────────────
# GTK needs pixbuf loaders to render images; copy and update the cache.

GDK_PIXBUF_DIR="${HOMEBREW_PREFIX}/lib/gdk-pixbuf-2.0"
if [ -d "${GDK_PIXBUF_DIR}" ]; then
    echo "Copying GDK pixbuf loaders..."
    mkdir -p "${APP_DIR}/Contents/Resources/lib"
    cp -R "${GDK_PIXBUF_DIR}" "${APP_DIR}/Contents/Resources/lib/"
fi

# ── 9. Bundle GLib schemas ────────────────────────────────────────────────────

SCHEMAS_DIR="${HOMEBREW_PREFIX}/share/glib-2.0/schemas"
if [ -d "${SCHEMAS_DIR}" ]; then
    echo "Copying GLib schemas..."
    mkdir -p "${APP_DIR}/Contents/Resources/share/glib-2.0"
    cp -R "${SCHEMAS_DIR}" "${APP_DIR}/Contents/Resources/share/glib-2.0/"
fi

# ── 10. Bundle Fonts ──────────────────────────────────────────────────────────
# Bundle fontconfig
if [ -d "${HOMEBREW_PREFIX}/etc/fonts" ]; then
    mkdir -p "${APP_DIR}/Contents/Resources/etc/fonts"
    cp -R "${HOMEBREW_PREFIX}/etc/fonts/" \
          "${APP_DIR}/Contents/Resources/etc/fonts/"
    echo "  Fontconfig bundled"
fi

# Bundle fonts
if [ -d "${HOMEBREW_PREFIX}/share/fonts" ]; then
    mkdir -p "${APP_DIR}/Contents/Resources/share/fonts"
    cp -R "${HOMEBREW_PREFIX}/share/fonts/" \
          "${APP_DIR}/Contents/Resources/share/fonts/"
    echo "  Fonts bundled"
fi
# Bundle hicolor icon theme
if [ -d "${HOMEBREW_PREFIX}/share/icons/hicolor" ]; then
    mkdir -p "${APP_DIR}/Contents/Resources/share/icons/hicolor"
    cp -R "${HOMEBREW_PREFIX}/share/icons/hicolor/" \
          "${APP_DIR}/Contents/Resources/share/icons/hicolor/"
fi

# Bundle Adwaita theme (provides check-symbolic.svg and other assets)
if [ -d "${HOMEBREW_PREFIX}/share/icons/Adwaita" ]; then
    mkdir -p "${APP_DIR}/Contents/Resources/share/icons/Adwaita"
    cp -R "${HOMEBREW_PREFIX}/share/icons/Adwaita/" \
          "${APP_DIR}/Contents/Resources/share/icons/Adwaita/"
fi

# Bundle GDK pixbuf loaders
GDK_PIXBUF_DIR="${HOMEBREW_PREFIX}/lib/gdk-pixbuf-2.0"
if [ -d "${GDK_PIXBUF_DIR}" ]; then
    mkdir -p "${APP_DIR}/Contents/Resources/lib/gdk-pixbuf-2.0"
    cp -R "${GDK_PIXBUF_DIR}/" \
          "${APP_DIR}/Contents/Resources/lib/gdk-pixbuf-2.0/"
    # Update the loaders.cache paths to point inside the bundle
    GDK_PIXBUF_CACHE="${APP_DIR}/Contents/Resources/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"
    if [ -f "${GDK_PIXBUF_CACHE}" ]; then
        sed -i '' "s|${HOMEBREW_PREFIX}/lib/gdk-pixbuf-2.0|@executable_path/../Resources/lib/gdk-pixbuf-2.0|g" \
            "${GDK_PIXBUF_CACHE}"
    fi
fi

# Bundle Pango
if [ -d "${HOMEBREW_PREFIX}/lib/pango" ]; then
    mkdir -p "${APP_DIR}/Contents/libs/pango"
    cp -R "${HOMEBREW_PREFIX}/lib/pango/" \
          "${APP_DIR}/Contents/libs/pango/"
fi

# Bundle fontconfig
mkdir -p "${APP_DIR}/Contents/Resources/etc/fonts"
if [ -d "${HOMEBREW_PREFIX}/etc/fonts" ]; then
    cp -R "${HOMEBREW_PREFIX}/etc/fonts/" \
          "${APP_DIR}/Contents/Resources/etc/fonts/"
fi
# Add system font fallback to fontconfig
cat >> "${APP_DIR}/Contents/Resources/etc/fonts/fonts.conf" << 'FONTCONF'
<dir>/Library/Fonts</dir>
<dir>/System/Library/Fonts</dir>
FONTCONF

# Bundle Denemo's own fonts (denemo.ttf etc)
if [ -d "${HOMEBREW_PREFIX}/share/fonts" ]; then
    mkdir -p "${APP_DIR}/Contents/Resources/share/fonts"
    cp -R "${HOMEBREW_PREFIX}/share/fonts/" \
          "${APP_DIR}/Contents/Resources/share/fonts/"
fi

# Bundle Ghostscript (required by LilyPond for PDF output)
GS_BIN=$(which gs || echo "${HOMEBREW_PREFIX}/bin/gs")
if [ -f "${GS_BIN}" ]; then
    cp "${GS_BIN}" "${APP_DIR}/Contents/MacOS/gs"
    dylibbundler -of -cd -b \
        -x "${APP_DIR}/Contents/MacOS/gs" \
        -d "${APP_DIR}/Contents/libs/" \
        -p "@executable_path/../libs/"
    echo "  Ghostscript bundled"
else
    echo "  WARNING: gs not found - LilyPond PDF output will fail"
fi

# ── 11. Create DMG ────────────────────────────────────────────────────────────

echo "Creating DMG: ${DMG_NAME}..."
rm -f "${DMG_NAME}"

create-dmg \
    --volname "Denemo ${DENEMO_VERSION}" \
    --volicon "${ICNS_OUT}" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "${APP_BUNDLE}" 150 185 \
    --hide-extension "${APP_BUNDLE}" \
    --app-drop-link 450 185 \
    "${DMG_NAME}" \
    "${STAGING_DIR}/" \
    2>&1 | tail -5 || {
        # create-dmg may exit non-zero on first run due to DS_Store; that's ok
        echo "  (create-dmg warning ignored)"
    }

echo ""
echo "Done: ${DMG_NAME}"
echo "  App bundle: ${APP_DIR}"
