# Universal Ren'Py Build

Build [Ren'Py 7.4.11](https://github.com/renpy/renpy) RAPT (Android Packaging Tool) from source with **16K page alignment** support for Google Play, wrapping the upstream [renpy-build](https://github.com/renpy/renpy-build) system.

## Features

- **16K page alignment** — all Android `.so` files use `max-page-size=16384`, compliant with Google Play's 2025 requirement
- **3 ABIs** — arm64-v8a, armeabi-v7a, x86_64
- **Official packaging** — uses Ren'Py's own `distribute.py` to produce `renpy-7.4.11-rapt.zip`
- **CI-ready** — GitHub Actions workflow builds and publishes to Releases

## Architecture

```
Makefile                        ← orchestration entry point
config.env                      ← version + build configuration
scripts/
    prepare-linux.sh            ← one-time Linux host setup (all platforms)
    download-tars.sh            ← download dependency source tarballs
    distribute.sh               ← package SDK + DLC zips (full)
    distribute-rapt.sh          ← package RAPT DLC only
    check-env.sh                ← verify prerequisites
patches/
    renpy-build/
        0001-android-16k-page-alignment.patch
        0002-fix-build-issues.patch
    renpy/
        0001-distribute-allow-env-override-git-describe.patch
    pygame_sdl2/                ← (empty — no patches needed)
stubs/
    Live2DCubismCore.h          ← minimal stub for Live2D header
work/                           ← (git-ignored) build workspace
output/                         ← final distribution files
```

## Quick Start — RAPT Build

### Prerequisites (Ubuntu 22.04)

```bash
sudo apt-get install -y \
    git build-essential ccache curl unzip autoconf \
    python-dev-is-python2 python3-dev python3-jinja2 \
    libssl-dev libbz2-dev
```

### Build & Package

```bash
# Clone → Patch → Download tarballs → Build Android → Package RAPT
make clone
make patch
make tars-android
make rapt
make dist-rapt

# Output: output/renpy-7.4.11-rapt.zip
```

### CI / GitHub Actions

Push a tag to trigger the workflow automatically:

```bash
git tag v7.4.11
git push origin v7.4.11
```

Or trigger manually from the Actions tab (workflow_dispatch).

# Build for specific platforms
make build BUILD_PLATFORMS=linux BUILD_ARCHS=x86_64

# Rebuild specific tasks after a change
make rebuild TASKS="renpython librenpy"
```

## Patches

| Patch | Description |
|-------|-------------|
| `renpy-build/0001-android-16k-page-alignment.patch` | Adds `-Wl,-z,max-page-size=16384` to Android LDFLAGS for all 3 ABIs |
| `renpy-build/0002-fix-build-issues.patch` | copytree Python 3.10 compat, SDL2 Wayland fix, armv7l sysroot URL fix |
| `renpy/0001-distribute-allow-env-override-git-describe.patch` | Allows `RENPY_GIT_DESCRIBE` env var override for shallow clones |

### Creating a Patch

```bash
cd work/renpy-build
# ... make changes ...
git diff > ../../patches/renpy-build/0003-description.patch
```

Patches are applied in alphabetical order. Use numbered prefixes (0001-, 0002-, ...) to control ordering.

## Full Platform Build

For building all platforms (Linux, Windows, macOS, Android, iOS), use the full pipeline:

```bash
sudo ./scripts/prepare-linux.sh   # install all cross-compilation tools
make check-env
make all                           # clone → patch → tars → build → dist
```

## License

This project wraps the upstream [renpy-build](https://github.com/renpy/renpy-build) and is subject to Ren'Py's licensing terms.
