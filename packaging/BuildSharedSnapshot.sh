#!/bin/bash
set -euo pipefail

# ==============================================================================
# BuildSharedSnapshot.sh — Build Denemo Windows package with bundled LilyPond
# ==============================================================================
# LILYPOND STRATEGY:
#   LilyPond lives in denemo/lilypond/ as a self-contained subdirectory.
#   Its DLLs are NOT merged into denemo/bin/ — doing so overwrites the GLib
#   DLLs Denemo was compiled against by MXE, causing the libglib crash.
#   Kept isolated, LilyPond uses its own DLLs and Denemo uses its own.
#   Configure Denemo to invoke:  lilypond\bin\lilypond.exe  (relative path)
#
# SIZE STRATEGY:
#   MXE pulls in many transitive deps (video codecs, ICU, crypto, terminfo…)
#   that Denemo never uses at runtime.  The cleanup section removes ~200 MB.
#   Items marked "MAYBE NEEDED" are uncertain — if Denemo breaks, restore them.
# ==============================================================================

MXE_PREFIX="${MXE_PREFIX:-usr/x86_64-w64-mingw32.shared}"
LILYPOND_SRC="${LILYPOND_SRC:-lilypond-2.24.4}"
VERSION="${VERSION:-2.6.52}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="${PKG:-denemo}"

# ------------------------------------------------------------------------------
# 1. Build Denemo via MXE
# ------------------------------------------------------------------------------
make update-package-denemo
make update-checksum-denemo
make denemo

# ------------------------------------------------------------------------------
# 2. Clean up any previous package
# ------------------------------------------------------------------------------
rm -f ./*.zip
rm -rf "${PKG}"
mkdir "${PKG}"

# ------------------------------------------------------------------------------
# 3. Install MXE-built files
#    Exclude build-time-only directories from rsync so they never land on disk.
# ------------------------------------------------------------------------------
rsync -a \
    --exclude='qt*'                  \
    --exclude='installed'            \
    --exclude='include'              \
    --exclude='info'                 \
    --exclude='var'                  \
    --exclude='ssl'                  \
    --exclude='lib/guile/2.2/ccache' \
    --exclude='lib/guile/3.0/ccache' \
    "${MXE_PREFIX}/" "${PKG}/"

# A few DLLs MXE sometimes misplaces
for dll in libfontconfig-1.dll libintl-8.dll; do
    src="${MXE_PREFIX}/bin/${dll}"
    [ -f "${src}" ] && cp "${src}" "${PKG}/bin/"
done

# ------------------------------------------------------------------------------
# 4. Fonts
# ------------------------------------------------------------------------------
mkdir -p "${PKG}/share/fonts"
for font in DejaVuSans.ttf DejaVuSans-Bold.ttf DejaVuSansMono.ttf; do
    src="/usr/share/fonts/truetype/dejavu/${font}"
    [ -f "${src}" ] && cp "${src}" "${PKG}/share/fonts/"
done
cp regfont.exe "${PKG}/bin/"
[ -f "${MXE_PREFIX}/bin/update-mime-database.exe" ] && cp "${MXE_PREFIX}/bin/update-mime-database.exe" "${PKG}/bin/" || echo "WARNING: update-mime-database.exe not found, skipping"
## 5. Guile pre-compiled .go files (compiled on Linux, bytecode is platform-independent)
#echo "Copying pre-compiled Guile .go files..."
#GUILE_JIT_THRESHOLD=-1 \
#rsync -a "${MXE_PREFIX}/lib/guile/3.0/ccache/" \
#         "${PKG}/lib/guile/3.0/ccache/"
#echo "  $(find "${PKG}/lib/guile/3.0/ccache" -name '*.go' | wc -l) .go files copied"
# ------------------------------------------------------------------------------
# 6. CLEANUP — delegated entirely to clean.sh
#    All removal logic lives there so it can also be run standalone.
#    clean.sh accepts the package directory as its first argument.
# ------------------------------------------------------------------------------
./clean.sh "${PKG}"

# ------------------------------------------------------------------------------
# 7. fontconfig config
# ------------------------------------------------------------------------------
mkdir -p "${PKG}/etc/fonts"
cat > "${PKG}/etc/fonts/fonts.conf" << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <dir prefix="cwd">share/fonts</dir>
  <cachedir prefix="cwd">fontconfig\cache</cachedir>
  <rescan><int>0</int></rescan>
</fontconfig>
EOF

# ------------------------------------------------------------------------------
# 8. GTK settings
# ------------------------------------------------------------------------------
mkdir -p "${PKG}/share/gtk-3.0"
cat > "${PKG}/share/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-icon-theme-name = hicolor
gtk-fallback-icon-theme = hicolor
gtk-enable-animations = false
gtk-toolbar-style = text
gtk-menu-images = false
gtk-button-images = false
gtk-enable-event-sounds = false
gtk-enable-input-feedback-sounds = false
EOF

mkdir -p "${PKG}/etc/gtk-3.0"
cat > "${PKG}/etc/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-icon-theme-name = hicolor
gtk-theme-name = Windows10
gtk-font-name = Sans 10
gtk-enable-animations = false
EOF

# ------------------------------------------------------------------------------
# 9. Generate GdkPixbuf loaders cache (needs Wine)
# ------------------------------------------------------------------------------
echo "Generating GdkPixbuf loaders cache..."
LOADERS_DIR="${PKG}/lib/gdk-pixbuf-2.0/2.10.0/loaders"
wine "${PKG}/bin/gdk-pixbuf-query-loaders.exe" \
    "${LOADERS_DIR}/libpixbufloader-gif.dll"  \
    "${LOADERS_DIR}/libpixbufloader-tiff.dll" \
    > "${PKG}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache" 2>/dev/null
echo "  loaders.cache written"

# ------------------------------------------------------------------------------
# 10. Generate GTK immodules cache (needs Wine)
# ------------------------------------------------------------------------------
echo "Generating GTK immodules cache..."
wine "${MXE_PREFIX}/bin/gtk-query-immodules-3.0.exe" \
    > "${PKG}/lib/gtk-3.0/3.0.0/immodules.cache"
echo "  immodules.cache written"

# ------------------------------------------------------------------------------
# 10b. Download and extract LilyPond if not already present
# ------------------------------------------------------------------------------
LILYPOND_ZIP="lilypond-2.24.4-mingw-x86_64.zip"
LILYPOND_URL="https://gitlab.com/lilypond/lilypond/-/releases/v2.24.4/downloads/${LILYPOND_ZIP}"
if [ ! -f "${LILYPOND_SRC}/bin/lilypond.exe" ]; then
    echo "Downloading LilyPond..."
    rm -rf "${LILYPOND_SRC}"
    wget -q --show-progress "${LILYPOND_URL}" -O "${LILYPOND_ZIP}"
    echo "Extracting LilyPond..."
    unzip -q "${LILYPOND_ZIP}"
    rm "${LILYPOND_ZIP}"
fi

echo "LilyPond source directory: ${LILYPOND_SRC}"
ls "${LILYPOND_SRC}/bin/lilypond.exe" || { echo "ERROR: LilyPond extraction failed"; exit 1; }

# ------------------------------------------------------------------------------
# 11. Install LilyPond into its OWN subdirectory — DO NOT merge into denemo/bin
# ------------------------------------------------------------------------------
echo "Installing LilyPond into ${PKG}/lilypond/ ..."
if [ -d "${LILYPOND_SRC}" ]; then
    rsync -a "${LILYPOND_SRC}/" "${PKG}/lilypond/"
    echo "  LilyPond installed ($(du -sh "${PKG}/lilypond" | cut -f1))"
else
    echo "  WARNING: ${LILYPOND_SRC} not found — LilyPond will NOT be bundled"
fi
# copy the wrapper scipt over
[ -d "${PKG}/lilypond/bin" ] && cp "${MXE_PREFIX}/bin/lilypond-windows.exe" "${PKG}/lilypond/bin/" || echo "WARNING: lilypond dir not found, skipping lilypond-windows.exe"

# ------------------------------------------------------------------------------
# 12. Launcher scripts
# ------------------------------------------------------------------------------
cp "${SCRIPT_DIR}/nsis/Denemo.bat" "${PKG}/" 2>/dev/null || cp "Denemo.bat" "${PKG}/"

# copy the denemo.ico over #TODO get this from denemo's src
mkdir -p "${PKG}/share/icons/hicolor/"
cp denemo.ico "${PKG}/share/icons/hicolor/denemo.ico"
cp org.denemo.Denemo.png "${PKG}/share/icons/hicolor/org.denemo.Denemo.png" 
# 12b. Precompile Denemo .scm files
echo "Precompiling Denemo scheme files..."
find "${PKG}/share/denemo" -name "*.scm" | while read scm; do
    rel="${scm#${PKG}/share/denemo/}"
    out="${PKG}/lib/guile/3.0/ccache/${rel%.scm}.go"
    mkdir -p "$(dirname "$out")"
    GUILE_JIT_THRESHOLD=-1 guild compile -o "$out" "$scm" 2>/dev/null || true
done
#
# 13.5  install license
#
mkdir -p "${PKG}/license/"
cp /usr/share/common-licenses/GPL-3 "${PKG}/license/denemo"

# ------------------------------------------------------------------------------
# 14. Final size report
# ------------------------------------------------------------------------------
echo ""
echo "=== Final package contents ==="
du -sh "${PKG}"/*/
echo "Total uncompressed: $(du -sh "${PKG}" | cut -f1)"

# ------------------------------------------------------------------------------
# 15. Zip and link
# ------------------------------------------------------------------------------
ZIP_NAME="denemo-${VERSION}.zip"
echo ""
echo "Creating ${ZIP_NAME} ..."
zip -r "${ZIP_NAME}" "${PKG}"
ln -sf "${ZIP_NAME}" denemo.zip

echo ""
echo "Done."
echo "  Package : ${ZIP_NAME}  ($(du -sh "${ZIP_NAME}" | cut -f1))"
echo "  Symlink : denemo.zip -> ${ZIP_NAME}"

#
# 16. Create installer
#
makensis -DVERSION=${VERSION} -DROOT=/home/jjbenham/public_html/mxe/denemo denemo.nsi
