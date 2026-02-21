#!/bin/bash
# check-env.sh — Verify build prerequisites for renpy-build.
#
# This checks that required tools and packages are installed.
set -euo pipefail

ERRORS=0

check_cmd() {
    if ! command -v "$1" &>/dev/null; then
        echo "  [MISSING] $1 — $2"
        ERRORS=$((ERRORS + 1))
    else
        echo "  [ok]      $1"
    fi
}

echo "==> Checking build prerequisites..."

# Core build tools
check_cmd git          "version control"
check_cmd python3      "needed to run renpy-build"
check_cmd make         "build system"
check_cmd clang-15     "C/C++ compiler (apt: clang-15)"
check_cmd lld-15       "LLVM linker (apt: lld-15)"
check_cmd ccache       "compiler cache"
check_cmd curl         "downloading source tarballs"
check_cmd tar          "extracting archives"
check_cmd pkg-config   "library discovery (apt: pkg-config)"
check_cmd autoconf     "autotools"

# Python dependencies for renpy-build
echo ""
echo "==> Checking Python 3 modules..."
python3 -c "import jinja2" 2>/dev/null && echo "  [ok]      jinja2" || {
    echo "  [MISSING] jinja2 — pip3 install jinja2"
    ERRORS=$((ERRORS + 1))
}
python3 -c "import Cython; v=Cython.__version__; assert int(v.split('.')[0]) < 3" 2>/dev/null && echo "  [ok]      Cython (<3)" || {
    echo "  [MISSING] Cython <3 — pip3 install 'Cython<3'"
    ERRORS=$((ERRORS + 1))
}

# Platform-specific checks
UNAME_S=$(uname -s)
echo ""
echo "==> Platform: $UNAME_S"

if [ "$UNAME_S" = "Linux" ]; then
    check_cmd debootstrap "creating sysroots for cross-compilation"
    check_cmd nasm        "assembly (libjpeg-turbo, ffmpeg)"
    check_cmd wayland-scanner "Wayland protocol scanner (apt: libwayland-dev)"

    echo ""
    echo "==> Checking Linux-specific packages..."
    for pkg in libssl-dev libbz2-dev liblzma-dev libgmp-dev libmpfr-dev libmpc-dev \
               libsdl2-dev libsdl2-image-dev libsdl2-ttf-dev libsdl2-mixer-dev \
               libharfbuzz-dev libbsd-dev libwayland-dev wayland-protocols \
               libfreetype6-dev libfribidi-dev libpng-dev zlib1g-dev \
               libavcodec-dev libavformat-dev libswresample-dev libswscale-dev; do
        if dpkg -s "$pkg" &>/dev/null; then
            echo "  [ok]      $pkg"
        else
            echo "  [MISSING] $pkg — sudo apt install $pkg"
            ERRORS=$((ERRORS + 1))
        fi
    done
fi

echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo "==> $ERRORS missing prerequisite(s). Install them and re-run."
    exit 1
else
    echo "==> All prerequisites satisfied."
fi
