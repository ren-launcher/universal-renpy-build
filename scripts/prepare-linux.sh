#!/bin/bash
# prepare-linux.sh — One-time setup for the Linux build host.
#
# This installs all system packages needed to build Ren'Py for supported
# platforms (linux, android) via cross-compilation using renpy-build.
#
# Usage: sudo ./scripts/prepare-linux.sh
set -euo pipefail

echo "==> Installing core build tools..."
apt-get update
apt-get install -y git build-essential ccache curl unzip zip

# Clang 15 + LLD 15 — required by renpy-build 7.6.x as the host/cross compiler
apt-get install -y clang-15 lld-15

# Python 3 dev headers + pip
apt-get install -y python3-dev python3-pip

# Python 3 jinja2 (needed by renpy-build itself)
apt-get install -y python3-jinja2

# Cython 0.29.x (renpy-build is incompatible with Cython 3.x)
pip3 install 'Cython<3'

# Sysroot creation for cross-compilation
apt-get install -y debootstrap

# Autotools, pkg-config
apt-get install -y autoconf automake libtool pkg-config

# Host python build requirements
apt-get install -y libssl-dev libbz2-dev liblzma-dev

# Native build dependencies (for host builds)
apt-get install -y \
    libsdl2-dev libsdl2-image-dev libsdl2-ttf-dev libsdl2-mixer-dev \
    libavcodec-dev libavformat-dev libswresample-dev libswscale-dev \
    libfreetype6-dev libpng-dev zlib1g-dev \
    libfribidi-dev libjpeg-dev \
    libharfbuzz-dev libbsd-dev \
    libwayland-dev wayland-protocols \
    nasm

# GCC cross-compiler build requirements (for building cross toolchains)
apt-get install -y libgmp-dev libmpfr-dev libmpc-dev

echo ""
echo "==> Linux build host setup complete."
echo ""
echo "Next steps:"
echo "  1. Run: make all"
