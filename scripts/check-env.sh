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
check_cmd gcc          "C compiler"
check_cmd g++          "C++ compiler"
check_cmd ccache       "compiler cache (optional but expected)"
check_cmd curl         "downloading source tarballs"
check_cmd patch        "applying patches"
check_cmd tar          "extracting archives"

# Python dependencies for renpy-build
echo ""
echo "==> Checking Python 3 modules..."
python3 -c "import jinja2" 2>/dev/null && echo "  [ok]      jinja2" || {
    echo "  [MISSING] jinja2 — pip3 install jinja2"
    ERRORS=$((ERRORS + 1))
}

# Platform-specific checks
UNAME_S=$(uname -s)
echo ""
echo "==> Platform: $UNAME_S"

if [ "$UNAME_S" = "Linux" ]; then
    check_cmd debootstrap "creating sysroots for cross-compilation"
    check_cmd nasm        "assembly (libjpeg-turbo, ffmpeg)"
    check_cmd autoconf    "autotools"
    check_cmd x86_64-w64-mingw32-gcc "Windows cross-compiler (apt: mingw-w64)"

    # Check for LLVM 13 (needed for iOS cross-compilation)
    check_cmd clang-13    "iOS cross-compilation (apt: from llvm.sh)"
    check_cmd llvm-ar-13  "iOS cross-compilation"
    check_cmd cmake       "macOS cross-compilation toolchain"

    echo ""
    echo "==> Checking Linux-specific packages..."
    for pkg in libssl-dev libbz2-dev libgmp-dev libmpfr-dev libmpc-dev; do
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
