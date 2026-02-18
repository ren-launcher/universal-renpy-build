# Universal Ren'Py Build

Build [Ren'Py](https://github.com/renpy/renpy) RAPT (Android Packaging Tool) from source with **16K page alignment** support for Google Play. Wraps the upstream [renpy-build](https://github.com/renpy/renpy-build) system with patches applied on top.

## Features

- **16K page alignment** — Android `.so` files use `max-page-size=16384`, compliant with Google Play requirements
- **3 ABIs** — arm64-v8a, armeabi-v7a, x86_64
- **Official packaging** — uses Ren'Py's own `distribute.py` to produce the RAPT DLC zip
- **CI-ready** — GitHub Actions workflow; push a tag to build and publish to Releases

## Project Structure

```
config.env                      ← version configuration (edit to switch Ren'Py version)
Makefile                        ← build entry point
scripts/
    prepare-linux.sh            ← system dependency installation (all platforms)
    download-tars.sh            ← download source tarballs
    distribute.sh               ← package full SDK + DLCs
    distribute-rapt.sh          ← package RAPT DLC only
    check-env.sh                ← verify build prerequisites
patches/
    renpy-build/                ← patches for renpy-build
    renpy/                      ← patches for renpy engine
    pygame_sdl2/                ← patches for pygame_sdl2
stubs/
    Live2DCubismCore.h          ← minimal Live2D header stub
work/                           ← build workspace (git-ignored)
output/                         ← final artifacts
```

## Quick Start — Build RAPT

### Prerequisites (Ubuntu 22.04)

```bash
sudo apt-get install -y \
    git build-essential ccache curl unzip autoconf \
    python-dev-is-python2 python3-dev python3-jinja2 \
    libssl-dev libbz2-dev
```

### Build & Package

```bash
make clone        # clone renpy-build, renpy, pygame_sdl2
make patch        # apply patches
make tars-android # download source tarballs (Android only)
make rapt         # build for all 3 Android ABIs
make dist-rapt    # package RAPT DLC via official tooling

ls output/        # renpy-<VERSION>-rapt.zip
```

### CI / GitHub Actions

Push a tag to trigger the workflow and publish to Releases:

```bash
git tag v<VERSION>
git push origin v<VERSION>
```

Or trigger manually from the Actions tab (workflow_dispatch).

## Version Configuration

All version settings are in `config.env`:

```env
RENPY_VERSION   = x.y.z
RENPY_TAG       = x.y.z.NNNN
RENPY_BUILD_TAG = renpy-x.y.z.NNNN
PYGAME_SDL2_TAG = renpy-x.y.z.NNNN
```

After editing, re-run `make clone patch tars-android rapt dist-rapt` to build for the new version.

## Patches

| Patch | Description |
|-------|-------------|
| `renpy-build/0001-android-16k-page-alignment.patch` | Add `-Wl,-z,max-page-size=16384` to Android LDFLAGS |
| `renpy-build/0002-fix-build-issues.patch` | copytree Python 3.10 compat, SDL2 Wayland fix, armv7l sysroot fix |
| `renpy/0001-distribute-allow-env-override-git-describe.patch` | Allow `RENPY_GIT_DESCRIBE` env override for shallow clones |

### Creating a Patch

```bash
cd work/renpy-build
# make changes...
git diff > ../../patches/renpy-build/0003-description.patch
```

Patches are applied in alphabetical order. Use numbered prefixes (0001-, 0002-, ...) to control ordering.

## Full Platform Build

To build for all platforms (Linux, Windows, macOS, Android, iOS):

```bash
sudo ./scripts/prepare-linux.sh
make check-env
make all
```

## Make Targets

| Target | Description |
|--------|-------------|
| `make clone` | Clone source repositories |
| `make patch` | Apply patches |
| `make tars-android` | Download tarballs (Android only) |
| `make tars` | Download all tarballs |
| `make rapt` | Build RAPT (Android) |
| `make dist-rapt` | Package RAPT DLC |
| `make build` | Build all platforms |
| `make dist` | Package full SDK + DLCs |
| `make clean` | Remove everything |
| `make clean-build` | Remove build artifacts (keep sources) |

## License

This project wraps the upstream [renpy-build](https://github.com/renpy/renpy-build) and is subject to Ren'Py's licensing terms.
