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

# ── Symlinks for rapt/renios ───────────────────────────────────────────────
rm -f rapt renios
if [ -d rapt2 ]; then ln -sf rapt2 rapt; fi
if [ -d renios2 ]; then ln -sf renios2 renios; fi

# Symlink pygame_sdl2 source if not present
if [ ! -e pygame_sdl2 ] && [ ! -L pygame_sdl2 ]; then
    ln -s "$PYGAME_SRC" pygame_sdl2
fi

# ── Detect python binary ──────────────────────────────────────────────────
PYTHON_BIN=""
for candidate in lib/py2-linux-x86_64/python lib/linux-x86_64/python; do
    if [ -f "$candidate" ]; then
        PYTHON_BIN="$candidate"
        break
    fi
done
if [ -z "$PYTHON_BIN" ]; then
    echo "ERROR: python binary not found in lib/"
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
# to the "main" branch (7.7.0) instead of "fix" (7.6.3). Write explicitly.
VC_VERSION=$(echo "$TAG" | rev | cut -d. -f1 | rev)
cat > renpy/vc_version.py <<EOF
version = "${VERSION}.${VC_VERSION}"
version_name = ""
official = False
nightly = False
branch = "fix"
EOF

# ── Environment ───────────────────────────────────────────────────────────
export RENPY_SIMPLE_EXCEPTIONS=1
export SDL_VIDEODRIVER=dummy

# Run tutorial to generate caches
echo "==> Pre-generating caches..."
./"$PYTHON_BIN" -O ./renpy.py tutorial quit 2>/dev/null || true

# Build the SDK distribution
echo "==> Building SDK distribution..."
./"$PYTHON_BIN" -O distribute.py "$VERSION" \
    --pygame "$PYGAME_SRC" \
    --fast \
    --nosign

# Move output to the target directory
if [ -d "dl/$VERSION" ]; then
    cp -a dl/"$VERSION"/* "$OUTPUT/" 2>/dev/null || true
fi

echo ""
echo "==> Distribution built in $OUTPUT/"
ls -lh "$OUTPUT/"
