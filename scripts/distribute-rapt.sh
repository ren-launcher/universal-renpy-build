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

# ── Symlinks (Python 2 builds use rapt2/, renios2/) ─────────────────
if [ -L rapt ]; then rm -f rapt; fi
if [ ! -e rapt ] && [ -d rapt2 ]; then ln -sf rapt2 rapt; fi

if [ -L renios ]; then rm -f renios; fi
if [ ! -e renios ] && [ -d renios2 ]; then ln -sf renios2 renios; fi

# Symlink pygame_sdl2 source if not present
if [ ! -e pygame_sdl2 ] && [ ! -L pygame_sdl2 ]; then
    ln -s "$PYGAME_SRC" pygame_sdl2
fi

# ── Verify linux-x86_64 runtime exists ─────────────────────────────────────
RENPY_BIN=""
for candidate in lib/py2-linux-x86_64/renpy lib/linux-x86_64/renpy; do
    if [ -f "$candidate" ]; then
        RENPY_BIN="$candidate"
        break
    fi
done
if [ -z "$RENPY_BIN" ]; then
    echo "ERROR: renpy binary not found in lib/py2-linux-x86_64/ or lib/linux-x86_64/"
    echo "A full build (including linux platform) is required."
    exit 1
fi

# ── Create stub for mac-universal (not built, but checked by distribute) ───
if [ ! -d lib/py2-mac-universal ] && [ ! -d lib/mac-x86_64 ]; then
    if [ -d lib/py2-linux-x86_64 ]; then
        mkdir -p lib/py2-mac-universal
        cp lib/py2-linux-x86_64/renpy lib/py2-mac-universal/renpy
    elif [ -d lib/linux-x86_64 ]; then
        mkdir -p lib/mac-x86_64
        cp lib/linux-x86_64/renpy lib/mac-x86_64/renpy
    fi
fi

# ── Write vc_version.py ───────────────────────────────────────────────────
# renpy/__init__.py imports official, nightly, version_name, version from
# vc_version.py. In detached HEAD state, generate_vc_version() would resolve
# to the "main" branch (7.7.0) instead of "fix" (7.6.3). Write the correct
# values explicitly.
VC_VERSION=$(echo "$TAG" | rev | cut -d. -f1 | rev)
cat > renpy/vc_version.py <<EOF
version = "${VERSION}.${VC_VERSION}"
version_name = ""
official = False
nightly = False
branch = "fix"
EOF

# ── Environment for distribute ────────────────────────────────────────────
export RENPY_SIMPLE_EXCEPTIONS=1
export SDL_VIDEODRIVER=dummy

echo "==> Building RAPT distribution package (version $VERSION)..."

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
