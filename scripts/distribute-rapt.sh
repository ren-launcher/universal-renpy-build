#!/bin/bash
# distribute-rapt.sh — Package the RAPT (Ren'Py Android Packaging Tool) DLC.
#
# Uses Ren'Py's official distribute mechanism to create renpy-VERSION-rapt.zip.
# Requires a full build (linux-x86_64 + android) so that renpy.sh works.
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

# ── Verify linux-x86_64 runtime exists ─────────────────────────────────────
if [ ! -f lib/linux-x86_64/renpy ]; then
    echo "ERROR: lib/linux-x86_64/renpy not found."
    echo "A full build (including linux platform) is required."
    exit 1
fi

# ── Create stub for mac-x86_64 (not built, but checked by distribute) ─────
if [ ! -d lib/mac-x86_64 ]; then
    mkdir -p lib/mac-x86_64
    cp lib/linux-x86_64/renpy lib/mac-x86_64/renpy
fi

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
