#!/bin/bash
set -euo pipefail
# CI-adapted build script for GitHub Actions
# Runs inside the ghcr.io/jbenham2015/mxe Docker container

export MXE_DIR="/opt/mxe"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Copy packaging files into MXE directory where script expects them
cp "${SCRIPT_DIR}/regfont.exe" "${MXE_DIR}/"
cp "${SCRIPT_DIR}/denemo.ico" "${MXE_DIR}/"
cp "${SCRIPT_DIR}/clean.sh" "${MXE_DIR}/"
cp "${SCRIPT_DIR}/nsis/Denemo.bat" "${MXE_DIR}/"
cp "${SCRIPT_DIR}/nsis/denemo.nsi" "${MXE_DIR}/"
cp "${SCRIPT_DIR}/nsis/lilypond-prepost.nsh" "${MXE_DIR}/"

# Get version from denemo.mk
export VERSION=$(grep -m1 '_VERSION' "${MXE_DIR}/src/denemo.mk" | grep -o '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*')

# Create denemo tarball from checked-out source
echo "Creating denemo tarball from source..."
# Generate configure script if not present
if [ ! -f configure ]; then
    echo "Running autoreconf..."
    AUTOCONF_OPTS="-fi"
    # gtkdocize may not be available, create stub if needed
    if ! command -v gtkdocize &>/dev/null; then
        echo "Creating gtkdocize stub..."
        mkdir -p /usr/local/bin
        echo "exit 0" >> /usr/local/bin/gtkdocize
        chmod +x /usr/local/bin/gtkdocize
    fi
    autoreconf -fi
fi
cd "${SCRIPT_DIR}/.."
find . -xtype l -delete 2>/dev/null || true
tar czf /tmp/denemo-${VERSION}.tar.gz \
    --transform "s,^\.,denemo-${VERSION}," \
    --exclude='.git' --exclude='*.o' --exclude='*.lo' --exclude='*.a' .
CHECKSUM=$(sha256sum /tmp/denemo-${VERSION}.tar.gz | cut -d' ' -f1)
echo "Tarball checksum: ${CHECKSUM}"
mkdir -p "${MXE_DIR}/pkg"
cp /tmp/denemo-${VERSION}.tar.gz "${MXE_DIR}/pkg/"
# Use our authoritative denemo.mk, then patch checksum into it
cp "${SCRIPT_DIR}/mxe/denemo.mk" "${MXE_DIR}/src/denemo.mk"
sed -i "s/\$(PKG)_CHECKSUM := .*/\$(PKG)_CHECKSUM := ${CHECKSUM}/" "${MXE_DIR}/src/denemo.mk"
rm -f "${MXE_DIR}/usr/x86_64-w64-mingw32.shared/installed/denemo"
rm -rf "${MXE_DIR}/tmp-denemo-x86_64-w64-mingw32.shared"

# Run the build from MXE directory
cd "${MXE_DIR}"

# Override variables for CI
export MXE_PREFIX="usr/x86_64-w64-mingw32.shared"
export LILYPOND_SRC=""  # skip LilyPond for now
# export VERSION=$(grep '$(PKG)_VERSION' src/denemo.mk | sed 's/.*:= *//')

# Build denemo from the tarball we just created
echo "Building denemo..."
make denemo MXE_TARGETS=x86_64-w64-mingw32.shared -j$(nproc)

# Skip the make steps at top of BuildSharedSnapshot.sh
# Patch the script to skip make calls and Wine steps
sed \
    -e 's|^make update-package-denemo||' \
    -e 's|^make update-checksum-denemo||' \
    -e 's|^make denemo||' \
    -e 's|^wine |echo "Skipping wine: |; s|wine .*$|&"|' \
    -e 's|makensis.*|makensis -DVERSION=${VERSION} -DROOT=${MXE_DIR}/denemo denemo.nsi|' \
    "${SCRIPT_DIR}/BuildSharedSnapshot.sh" > /tmp/BuildCI_patched.sh

chmod +x /tmp/BuildCI_patched.sh
bash /tmp/BuildCI_patched.sh

# Copy installer to workspace for artifact upload
cp "${MXE_DIR}"/Denemo-*.exe "${GITHUB_WORKSPACE}/" 2>/dev/null || \
cp "${MXE_DIR}"/*.exe "${GITHUB_WORKSPACE}/"
