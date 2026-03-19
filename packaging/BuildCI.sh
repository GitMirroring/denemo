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

# Run the build from MXE directory
cd "${MXE_DIR}"

# Override variables for CI
export MXE_PREFIX="usr/x86_64-w64-mingw32.shared"
export LILYPOND_SRC=""  # skip LilyPond for now
export VERSION=$(grep '$(PKG)_VERSION' src/denemo.mk | sed 's/.*:= *//')

# Skip the make steps at top of BuildSharedSnapshot.sh
# Denemo is already built in the Docker image
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
