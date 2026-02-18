#!/bin/bash
# distribute.sh — Build the final SDK and DLC distribution packages.
#
# This script runs after renpy-build has compiled everything. It invokes
# Ren'Py's distribute.py to create the SDK zip/tar and DLC packages.
#
# Usage: distribute.sh <renpy_src> <pygame_sdl2_src> <build_root> <tmp>
#                       <version> <tag> <output_dir>
set -euo pipefail

RENPY_SRC="${1:?}"
PYGAME_SRC="${2:?}"
BUILD_ROOT="${3:?}"
TMP="${4:?}"
VERSION="${5:?}"
TAG="${6:?}"
OUTPUT="${7:?}"

mkdir -p "$OUTPUT"

cd "$RENPY_SRC"

# Ensure lib/ symlink points to lib2/ (Python 2 builds)
rm -f lib rapt renios
ln -sf lib2 lib
ln -sf rapt2 rapt
ln -sf renios2 renios

# Symlink pygame_sdl2 source if not present
if [ ! -e pygame_sdl2 ] && [ ! -L pygame_sdl2 ]; then
    ln -s "$PYGAME_SRC" pygame_sdl2
fi

# Write vc_version.py
VC_VERSION=$(echo "$TAG" | rev | cut -d. -f1 | rev)
printf "vc_version = %s\n" "$VC_VERSION" > renpy/vc_version.py

# Set up environment — use the host python built by renpy-build
HOST_PYTHON="$TMP/host/bin/python2"
if [ ! -x "$HOST_PYTHON" ]; then
    echo "ERROR: Host python not found at $HOST_PYTHON"
    echo "Make sure 'make build' ran successfully first."
    exit 1
fi

export RENPY_DEPS_INSTALL=/usr::/usr/lib/x86_64-linux-gnu/
export RENPY_CYTHON=cython
export RENPY_SIMPLE_EXCEPTIONS=1

# Generate Cython sources if needed
export SDL_VIDEODRIVER=dummy

# Run tutorial to generate caches
echo "==> Pre-generating caches..."
./lib/linux-x86_64/python -O ./renpy.py tutorial quit 2>/dev/null || true

# Build the SDK distribution
echo "==> Building SDK distribution..."
./lib/linux-x86_64/python -O distribute.py "$VERSION" \
    --pygame "$PYGAME_SRC" \
    --destination "$OUTPUT" \
    --no-update

echo ""
echo "==> Distribution built in $OUTPUT/"
ls -lh "$OUTPUT/"
