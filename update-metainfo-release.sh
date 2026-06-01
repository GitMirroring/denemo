#!/bin/bash
# update-metainfo-release.sh
# Run from the root of the denemo source tree

set -e

CONFIGURE_AC="configure.ac"
METAINFO="org.denemo.Denemo.metainfo.xml.in"

# Extract version from configure.ac
VERSION=$(grep -m1 'AC_INIT' "$CONFIGURE_AC" | grep -oP '(?<=\[)\d+\.\d+\.\d+(?=\])')

if [ -z "$VERSION" ]; then
  echo "Error: could not extract version from $CONFIGURE_AC"
  exit 1
fi

# Use today's date, or pass one as argument: ./update-metainfo-release.sh 2026-05-30
DATE="${1:-$(date +%Y-%m-%d)}"

NEW_RELEASE="  <release type=\"stable\" version=\"$VERSION\" date=\"$DATE\" />"

# Check if this version is already in the file
if grep -q "version=\"$VERSION\"" "$METAINFO"; then
  echo "Version $VERSION already present in $METAINFO — nothing to do."
  exit 0
fi

# Insert new release as first entry after <releases>
sed -i "s|<releases>|<releases>\n$NEW_RELEASE|" "$METAINFO"

echo "Added: $NEW_RELEASE"
