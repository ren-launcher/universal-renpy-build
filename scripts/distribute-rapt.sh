#!/bin/bash
# distribute-rapt.sh — Package the RAPT (Ren'Py Android Packaging Tool) DLC.
#
# Uses Ren'Py's official distribute mechanism to create renpy-VERSION-rapt.zip.
# This script handles the quirks needed for RAPT-only packaging:
#   - Symlinks lib→lib2, rapt→rapt2
#   - Creates stub executables for platforms not built (linux-i686, mac-x86_64)
#   - Sets RENPY_GIT_DESCRIBE for shallow-clone compatibility
#
# Usage: distribute-rapt.sh <renpy_src> <pygame_sdl2_src> <build_root> <tmp>
#                            <version> <tag> <output_dir>
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

# ── Symlinks (Python 2 builds use lib2/, rapt2/, renios2/) ─────────────────
rm -f lib rapt renios
ln -sf lib2 lib
ln -sf rapt2 rapt
ln -sf renios2 renios

# Symlink pygame_sdl2 source if not present
if [ ! -e pygame_sdl2 ] && [ ! -L pygame_sdl2 ]; then
    ln -s "$PYGAME_SRC" pygame_sdl2
fi

# ── Create stub executables for missing platforms ──────────────────────────
# distribute.py's add_python() checks for lib/linux-i686/renpy and
# lib/mac-x86_64/renpy. Since we only build Android + linux-x86_64 (host),
# we need stubs for the others.
for stub_platform in linux-i686 mac-x86_64; do
    stub_dir="lib/$stub_platform"
    if [ ! -d "$stub_dir" ]; then
        mkdir -p "$stub_dir"
        if [ -f lib/linux-x86_64/renpy ]; then
            cp lib/linux-x86_64/renpy "$stub_dir/renpy"
        fi
    fi
done

# ── Write vc_version.py ───────────────────────────────────────────────────
VC_VERSION=$(echo "$TAG" | rev | cut -d. -f1 | rev)
printf "vc_version = %s\n" "$VC_VERSION" > renpy/vc_version.py

# ── Environment for distribute ────────────────────────────────────────────
export RENPY_GIT_DESCRIBE="start-${VERSION%.*}-${VC_VERSION}-g$(git rev-parse --short HEAD)"
export RENPY_SIMPLE_EXCEPTIONS=1
export SDL_VIDEODRIVER=dummy

echo "==> RENPY_GIT_DESCRIBE=$RENPY_GIT_DESCRIBE"
echo "==> Building RAPT distribution package..."

# Use the official Ren'Py distribute mechanism
./renpy.sh launcher distribute launcher \
    --package rapt \
    --destination "dl/$VERSION" \
    --no-update

# ── Copy output ──────────────────────────────────────────────────────────
if [ -d "dl/$VERSION" ]; then
    cp -a dl/"$VERSION"/* "$OUTPUT/" 2>/dev/null || true
fi

echo ""
echo "==> RAPT distribution built in $OUTPUT/"
ls -lh "$OUTPUT/"
