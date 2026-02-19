#!/bin/bash
# prepare-linux.sh — One-time setup for the Linux build host.
#
# This installs all system packages needed to build Ren'Py 7.4.11 for all
# supported platforms (Linux, Windows, macOS, Android, iOS) via cross-compilation.
#
# Based on upstream renpy-build/prepare.sh (tag renpy-7.4.11.2266).
#
# Usage: sudo ./scripts/prepare-linux.sh
set -euo pipefail

echo "==> Installing core build tools..."
apt-get update
apt-get install -y git build-essential ccache curl unzip

# Python 3 dev headers + Cython (needed by renpy-build to compile .pyx files)
# Note: python-dev-is-python2 is unavailable on Ubuntu 24.04+.
# Not needed — renpy-build compiles Python 2.7.18 from source.
apt-get install -y python3-dev cython3

# Python 3 jinja2 (needed by renpy-build itself)
apt-get install -y python3-jinja2

# Sysroot creation for cross-compilation
apt-get install -y debootstrap qemu-user-static

# GCC cross-compiler build requirements
apt-get install -y libgmp-dev libmpfr-dev libmpc-dev

# Host python build requirements
apt-get install -y libssl-dev libbz2-dev

# MinGW for Windows cross-compilation
apt-get install -y mingw-w64 autoconf

# macOS cross-compilation (osxcross)
DEBIAN_FRONTEND=noninteractive apt-get install -y cmake clang libxml2-dev llvm

# LLVM 13 for iOS cross-compilation
if ! command -v clang-13 &>/dev/null; then
    echo "==> Installing LLVM 13..."
    wget -q https://apt.llvm.org/llvm.sh -O /tmp/llvm.sh
    chmod +x /tmp/llvm.sh
    /tmp/llvm.sh 13
    rm -f /tmp/llvm.sh
fi

# Native build dependencies (for host builds)
apt-get install -y \
    libavcodec-dev libavformat-dev \
    libswresample-dev libswscale-dev libfreetype6-dev libglew1.6-dev \
    libfribidi-dev libsdl2-dev libsdl2-image-dev \
    libjpeg-turbo8-dev nasm yasm

# Patchelf for Linux binary post-processing
apt-get install -y patchelf

echo ""
echo "==> Linux build host setup complete."
echo ""
echo "Next steps:"
echo "  1. Obtain MacOSX10.10.sdk.tar.bz2 and place it in work/renpy-build/tars/"
echo "  2. Run: make all"
