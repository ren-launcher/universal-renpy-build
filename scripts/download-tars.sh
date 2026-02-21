#!/bin/bash
# download-tars.sh — Download source tarballs needed by renpy-build.
#
# The upstream renpy-build expects source tarballs in its source/ directory.
# This script checks for each required tarball and downloads any that are
# missing from their canonical upstream locations.
#
# Usage: download-tars.sh <renpy-build-root>
set -euo pipefail

BUILD_ROOT="${1:?Usage: download-tars.sh <renpy-build-root> [--android-only]}"
ANDROID_ONLY=0
if [ "${2:-}" = "--android-only" ]; then
    ANDROID_ONLY=1
fi
SOURCE_DIR="$BUILD_ROOT/source"

mkdir -p "$SOURCE_DIR"

# ── Tarball registry: <filename> <url> ──────────────────────────────────────
declare -A TARBALLS=(
    ["Python-2.7.18.tgz"]="https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tgz"
    ["SDL2-2.0.14.tar.gz"]="https://www.libsdl.org/release/SDL2-2.0.14.tar.gz"
    ["SDL2_image-2.0.5.tar.gz"]="https://www.libsdl.org/projects/SDL_image/release/SDL2_image-2.0.5.tar.gz"
    ["ffmpeg-4.3.1.tar.gz"]="https://ffmpeg.org/releases/ffmpeg-4.3.1.tar.gz"
    ["freetype-2.10.1.tar.gz"]="https://downloads.sourceforge.net/freetype/freetype-2.10.1.tar.gz"
    ["fribidi-1.0.7.tar.bz2"]="https://github.com/fribidi/fribidi/releases/download/v1.0.7/fribidi-1.0.7.tar.bz2"
    ["libffi-3.3.tar.gz"]="https://github.com/libffi/libffi/releases/download/v3.3/libffi-3.3.tar.gz"
    ["libjpeg-turbo-1.5.3.tar.gz"]="https://downloads.sourceforge.net/libjpeg-turbo/libjpeg-turbo-1.5.3.tar.gz"
    ["libpng-1.6.37.tar.gz"]="https://downloads.sourceforge.net/libpng/libpng-1.6.37.tar.gz"
    ["libwebp-1.1.0.tar.gz"]="https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.1.0.tar.gz"
    ["nasm-2.14.02.tar.gz"]="https://www.nasm.us/pub/nasm/releasebuilds/2.14.02/nasm-2.14.02.tar.gz"
    ["openssl-1.1.1g.tar.gz"]="https://www.openssl.org/source/old/1.1.1/openssl-1.1.1g.tar.gz"
    ["zlib-1.2.11.tar.gz"]="https://zlib.net/fossils/zlib-1.2.11.tar.gz"
    ["bzip2-1.0.8.tar.gz"]="https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz"
    ["pyjnius-1.2.1.tar.gz"]="https://github.com/kivy/pyjnius/archive/refs/tags/1.2.1.tar.gz"
    ["pyobjus-1.1.0.tar.gz"]="https://github.com/kivy/pyobjus/archive/refs/tags/1.1.0.tar.gz"
)

# Also copy the Setup.local template and other non-tarball source files
# These are already in renpy-build/source/ from git clone, so we only
# need to download the tarballs.

FAIL=0
for name in "${!TARBALLS[@]}"; do
    target="$SOURCE_DIR/$name"
    if [ -f "$target" ]; then
        echo "  [ok] $name"
        continue
    fi

    url="${TARBALLS[$name]}"
    echo "  [dl] $name <- $url"
    if ! curl -fSL --retry 3 --retry-delay 5 -o "$target.tmp" "$url"; then
        echo "  [FAIL] Could not download $name"
        rm -f "$target.tmp"
        FAIL=1
        continue
    fi
    mv "$target.tmp" "$target"
done

if [ "$FAIL" -ne 0 ]; then
    echo ""
    echo "ERROR: Some tarballs failed to download. Check URLs and retry."
    exit 1
fi

# Also ensure zsync tarball is present (it's in patches/ in upstream)
ZSYNC_SRC="$BUILD_ROOT/patches/zsync-0.6.2.tar.bz2"
ZSYNC_DST="$SOURCE_DIR/zsync-0.6.2.tar.bz2"
if [ -f "$ZSYNC_SRC" ] && [ ! -f "$ZSYNC_DST" ]; then
    cp "$ZSYNC_SRC" "$ZSYNC_DST"
fi

# ── Toolchain tarballs (tars/ directory) ────────────────────────────────────
# These are large GNU/SDK tarballs needed by tasks/toolchain.py.
# Upstream expects them in renpy-build/tars/ (not source/).
TARS_DIR="$BUILD_ROOT/tars"
mkdir -p "$TARS_DIR"

declare -A TOOLCHAIN_TARBALLS=(
    ["android-ndk-r25c-linux.zip"]="https://dl.google.com/android/repository/android-ndk-r25c-linux.zip"
)

# Cross-compilation toolchains (not needed for Android-only builds)
if [ "$ANDROID_ONLY" -eq 0 ]; then
    TOOLCHAIN_TARBALLS+=(
        ["binutils-2.33.1.tar.gz"]="https://ftp.gnu.org/gnu/binutils/binutils-2.33.1.tar.gz"
        ["gcc-9.2.0.tar.gz"]="https://ftp.gnu.org/gnu/gcc/gcc-9.2.0/gcc-9.2.0.tar.gz"
    )
fi

for name in "${!TOOLCHAIN_TARBALLS[@]}"; do
    target="$TARS_DIR/$name"
    if [ -f "$target" ]; then
        echo "  [ok] $name (tars/)"
        continue
    fi

    url="${TOOLCHAIN_TARBALLS[$name]}"
    echo "  [dl] $name <- $url"
    if ! curl -fSL --retry 3 --retry-delay 5 -o "$target.tmp" "$url"; then
        echo "  [FAIL] Could not download $name"
        rm -f "$target.tmp"
        FAIL=1
        continue
    fi
    mv "$target.tmp" "$target"
done

if [ "$FAIL" -ne 0 ]; then
    echo ""
    echo "ERROR: Some toolchain tarballs failed to download. Check URLs and retry."
    exit 1
fi

echo ""
echo "==> All source tarballs ready in $SOURCE_DIR"
