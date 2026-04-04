#!/bin/sh
# autogen.sh - Generate build system files
# Handles macOS/Homebrew, Linux, and other POSIX platforms.

set -e

# ── 1. Locate tools, handling platform differences ────────────────────────────

# libtoolize is called glibtoolize on macOS (Homebrew/MacPorts)
if command -v glibtoolize > /dev/null 2>&1; then
    LIBTOOLIZE="glibtoolize"
elif command -v libtoolize > /dev/null 2>&1; then
    LIBTOOLIZE="libtoolize"
else
    echo "ERROR: neither libtoolize nor glibtoolize found." >&2
    echo "  macOS:  brew install libtool" >&2
    echo "  Debian: apt install libtool" >&2
    exit 1
fi

for tool in aclocal autoheader automake autoconf intltoolize; do
    if ! command -v "$tool" > /dev/null 2>&1; then
        echo "ERROR: '$tool' not found. Please install autoconf/automake/intltool." >&2
        exit 1
    fi
done

# ── 2. Build a portable ACLOCAL_PATH ─────────────────────────────────────────
#
# aclocal needs to find .m4 files from installed packages. On Homebrew this is
# NOT /usr/share/aclocal. We probe known locations and add existing ones.

ACLOCAL_SEARCH_DIRS="
    /usr/share/aclocal
    /usr/local/share/aclocal
    /opt/homebrew/share/aclocal
    /opt/local/share/aclocal
    /sw/share/aclocal
"

# Build -I flags for each directory that actually exists
EXTRA_ACLOCAL_FLAGS=""
for dir in $ACLOCAL_SEARCH_DIRS; do
    if [ -d "$dir" ]; then
        EXTRA_ACLOCAL_FLAGS="$EXTRA_ACLOCAL_FLAGS -I $dir"
    fi
done

# Merge with any user-supplied ACLOCAL_FLAGS, project-local m4/ or build/ dir
ACLOCAL_FLAGS="-I build $ACLOCAL_FLAGS $EXTRA_ACLOCAL_FLAGS"

# ── 3. Run the Autotools sequence ─────────────────────────────────────────────

echo "Running aclocal $ACLOCAL_FLAGS ..."
aclocal $ACLOCAL_FLAGS

echo "Running autoheader ..."
autoheader

echo "Running $LIBTOOLIZE ..."
$LIBTOOLIZE --force --copy

echo "Running intltoolize ..."
intltoolize --copy --force --automake

echo "Running automake ..."
automake --add-missing --gnu --copy

echo "Running autoconf ..."
autoconf

echo ""
echo "Done. Now run:  ./configure"
