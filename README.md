# Universal Ren'Py Build

Build the complete Ren'Py 7.4.11 distribution (SDK + RAPT + renios DLCs) entirely from source, wrapping the upstream [renpy-build](https://github.com/renpy/renpy-build) system with our patches.

## Architecture

```
Makefile                        ← orchestration entry point
config.env                      ← version + build configuration
scripts/
    prepare-linux.sh            ← one-time Linux host setup
    download-tars.sh            ← download dependency source tarballs
    distribute.sh               ← package SDK + DLC zips
    check-env.sh                ← verify prerequisites
patches/
    renpy-build/                ← patches on top of upstream renpy-build
    renpy/                      ← patches on top of renpy engine source
    pygame_sdl2/                ← patches on top of pygame_sdl2
work/                           ← (git-ignored) build workspace
    renpy-build/                ← upstream renpy-build (cloned)
    renpy/                      ← upstream renpy source (cloned)
    pygame_sdl2/                ← upstream pygame_sdl2 (cloned)
    tmp/                        ← renpy-build temp (sysroots, cross, install, ...)
output/                         ← final distribution files
```

## How It Works

This project wraps the upstream `renpy-build` system rather than reimplementing it:

1. **Clone** — checks out `renpy-build`, `renpy`, and `pygame_sdl2` at the configured tags
2. **Patch** — applies any patches from `patches/` on top of the upstream sources
3. **Download** — fetches dependency source tarballs (Python, SDL2, FFmpeg, etc.)
4. **Build** — runs `renpy-build/build.py` which handles:
   - Cross-compilation toolchains (Linux → Windows/macOS/Android/iOS)
   - All C dependencies (Python 2.7.18, SDL2, FFmpeg, OpenSSL, etc.)
   - pygame_sdl2 + Ren'Py C modules → static `librenpy.a` → `librenpython.so`
   - Python standard library packaging
5. **Distribute** — runs Ren'Py's `distribute.py` to produce SDK + DLC packages

## Quick Start

### Prerequisites (Ubuntu 22.04)

```bash
# One-time setup — installs all build tools + cross-compilers
sudo ./scripts/prepare-linux.sh

# Check prerequisites
make check-env
```

### Build

```bash
# Full build: all platforms + SDK distribution
make all

# Build only (skip distribution packaging)
make build

# Build for specific platforms
make build BUILD_PLATFORMS=linux BUILD_ARCHS=x86_64

# Rebuild specific tasks after a change
make rebuild TASKS="renpython librenpy"
```

### Platform-Specific Builds

```bash
# Linux only
make build BUILD_PLATFORMS=linux

# Linux + Windows (cross-compiled from Linux)
make build BUILD_PLATFORMS=linux,windows

# All desktop platforms
make build BUILD_PLATFORMS=linux,windows,mac

# Android
make build BUILD_PLATFORMS=android

# iOS (requires LLVM 13 on Linux, or Xcode on macOS)
make build BUILD_PLATFORMS=ios
```

### Output

```bash
ls output/
# renpy-7.4.11-sdk.zip
# renpy-7.4.11-sdk.tar.bz2
# renpy-7.4.11-rapt.zip
# renpy-7.4.11-renios.zip
```

## Patches

Patches are organized by target repository:

- **`patches/renpy-build/`** — modifications to the build system itself
- **`patches/renpy/`** — modifications to the Ren'Py engine source
- **`patches/pygame_sdl2/`** — modifications to pygame_sdl2

### Creating a Patch

```bash
# Example: fix something in renpy-build
cd work/renpy-build
# ... make changes ...
git diff > ../../patches/renpy-build/0001-description.patch
```

Patches are applied in alphabetical order. Use numbered prefixes (0001-, 0002-, ...) to control ordering.

## Differences from Upstream renpy-build

The upstream `renpy-build` is designed to run on Tom Rothamel's personal build server with hardcoded paths and assumptions. This project:

- **Portable** — no hardcoded paths; everything is relative or configurable
- **Self-contained** — downloads all dependencies; no pre-populated directories needed
- **Documented** — clear build stages and configuration
- **CI-ready** — designed for GitHub Actions workflows
- **Patch-based** — all modifications tracked as patches, easy to update when upstream changes

## Version History

| Branch        | Ren'Py | Build System                 |
| ------------- | ------ | ---------------------------- |
| `main`        | 7.4.11 | Wraps upstream renpy-build   |
| `renpy-7.3.5` | 7.3.5  | Custom Makefile + renpy-deps |

## Cross-Compilation Notes

The upstream renpy-build handles all cross-compilation from a Linux host:

- **Linux** — custom GCC 9.2 + Xenial sysroot (via debootstrap)
- **Windows** — MinGW-w64 (x86_64, i686)
- **macOS** — osxcross with MacOSX 10.10 SDK
- **Android** — NDK r21d unified toolchains
- **iOS** — LLVM/Clang 13 with extracted Xcode SDK
- **Web** — Emscripten (WASM)
