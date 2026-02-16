# Universal Ren'Py Build

Build the complete Ren'Py 7.3.5 distribution (SDK + RAPT Android DLC + renios iOS DLC) entirely from source, with no prebuilt downloads. Supports multi-platform builds via CI (Linux x86_64 + macOS x86_64).

## Architecture

```
Makefile                        <- single orchestration entry point
    │
    └─ work/
        ├─ renpy-deps/          <- upstream: C dependency builds (Python 2.7, SDL2, FFmpeg, ...)
        │   ├─ build_python.sh      Python + zlib + bz2 + openssl
        │   ├─ build.sh             SDL2/image/ttf/mixer + freetype + ffmpeg + glew
        │   ├─ build_mac.sh         macOS wrapper (MACOSX_DEPLOYMENT_TARGET=10.6)
        │   └─ renpython/           PyInstaller packaging -> lib/<platform>/
        │
        ├─ renpy/               <- upstream: Ren'Py engine source
        │   ├─ module/              C extension modules (Cython -> .so)
        │   └─ launcher/            distribute system -> SDK/DLC zips
        │
        ├─ rapt/                <- upstream: Android packaging tool
        │   └─ native/build.sh      NDK cross-compile -> ARM .so
        │
        ├─ renios/              <- upstream: iOS packaging tool
        │   ├─ build_all.sh         Xcode cross-compile -> iOS/Simulator libs
        │   └─ prototype/           Xcode project template
        │
        └─ pygame_sdl2/         <- upstream: SDL2 Python bindings
```

## Quick Start

### System Dependencies

**Linux (Ubuntu/Debian)**:

```bash
sudo apt-get install -y \
  build-essential ccache patchelf \
  libgl1-mesa-dev libglu1-mesa-dev \
  libasound2-dev libpulse-dev \
  libx11-dev libxext-dev libxrandr-dev libxi-dev libxfixes-dev \
  libxcursor-dev libxss-dev libxinerama-dev libxxf86vm-dev \
  libxmu-dev \
  libdbus-1-dev libudev-dev \
  python2 python2-dev virtualenv \
  nasm yasm
```

**macOS (Apple Silicon / arm64)**:

```bash
# Build tools
brew install nasm yasm libtool coreutils

# Python 2.7 (required by Ren'Py 7.x build scripts)
brew install pyenv
pyenv install 2.7.18
pyenv shell 2.7.18
python -m virtualenv work/py2-venv

# Xcode with command-line tools (required for renios)
xcode-select --install

# Rosetta 2 (required on Apple Silicon — deps Python 2.7.10 is x86_64 only)
softwareupdate --install-rosetta --agree-to-license
```

> **Note**: `ccache` is optional — patches make it a no-op if absent.
> The build runs under Rosetta 2 on Apple Silicon for the deps stage;
> renios cross-compiles natively for arm64 iOS / x86_64 Simulator.

### Build

```bash
# Linux: builds SDK (linux-x86_64) + RAPT DLC
make all

# macOS: builds SDK (darwin-x86_64) + renios DLC
make all

# Individual targets
make sdk              # SDK only
make lib-only         # lib/<platform> only (for CI)
make dist-rapt        # RAPT DLC only (Linux)
make dist-renios      # renios DLC only (macOS)
make rapt-native      # RAPT native .so only
make renios-native    # renios native libs only
```

Output goes to `output/`.

### Multi-platform Merge (CI)

```bash
# Merge libs from other platform builds into the SDK
make sdk EXTRA_LIBS=/path/to/extra-libs
# EXTRA_LIBS should contain subdirs: darwin-x86_64/, linux-x86_64/, etc.
```

### Other Commands

```bash
make help         # Show all available targets
make clean        # Remove everything (including source clones)
make clean-deps   # Remove C dependencies only (keep source clones)
make clean-rapt   # Remove RAPT build artifacts only
```

## Build Pipeline

```
make all (Linux)
  │
  ├─ clone          git clone renpy, rapt, pygame_sdl2, renpy-deps, renios
  ├─ patched-renpy  git am patches/renpy/*.patch
  ├─ patched-rapt   git am patches/rapt/*.patch
  ├─ patched-renios git am patches/renios/*.patch
  │
  ├─ deps           build_python.sh + build.sh -> C dependency libraries
  ├─ modules        pygame_sdl2 + renpy/module -> Python extensions
  ├─ lib            renpython/build.py + merge.py -> lib/linux-x86_64/
  ├─ merge-libs     (optional) import lib/ from other platforms
  ├─ sdk            ./renpy.sh launcher distribute -> SDK zip
  │
  ├─ cython-venv    Python 2 + Cython virtualenv
  ├─ rapt-native    native/build.sh -> Android .so (16K aligned)
  └─ dist-rapt      inject rapt -> distribute -> RAPT DLC zip

make all (macOS)
  │
  ├─ clone/patch    (same as above)
  ├─ deps           build_mac.sh -> C dependencies (MACOSX_DEPLOYMENT_TARGET=10.6)
  ├─ modules/lib    -> lib/darwin-x86_64/
  ├─ sdk            -> SDK zip
  │
  ├─ renios-native  build_all.sh -> iOS/Simulator native libraries
  └─ dist-renios    inject renios -> distribute -> renios DLC zip
```

## Patch Management

All upstream source modifications are recorded as `git format-patch` files under `patches/`:

```
patches/
├── rapt/
│   ├── 0001-Add-16K-page-alignment-support-for-Google-Play.patch
│   └── 0002-Fix-build-compatibility-with-NDK-r19c-clang.patch
├── renios/
│   └── 0001-Use-RENPY_ROOT-env-var-in-copy_renpy.sh.patch
└── renpy/
    ├── 0001-Fix-distribute.py-hardcoded-paths-for-portable-build.patch
    ├── 0002-Fix-launcher-options.rpy-hardcoded-Mac-signing-paths.patch
    └── 0003-Skip-missing-platform-binaries-in-distribute-add_pyt.patch
```

### Creating a New Patch

```bash
cd work/<repo>
# make changes...
git add -A && git commit -m "Describe the change"
git format-patch -1 -o ../../patches/<repo>/
```

### Viewing Applied Patches

```bash
cd work/<repo> && git log --oneline
```

## CI/CD

The GitHub Actions workflow at `.github/workflows/build.yml` uses a multi-runner architecture:

| Job           | Runner          | Produces                                            |
| ------------- | --------------- | --------------------------------------------------- |
| `build-linux` | `ubuntu-22.04`  | `lib/linux-x86_64/` + RAPT native `.so`             |
| `build-mac`   | `macos-13`      | `lib/darwin-x86_64/` + renios native libs           |
| `package`     | `ubuntu-22.04`  | Merges all libs, builds SDK + RAPT DLC + renios DLC |
| `release`     | `ubuntu-latest` | Creates GitHub Release from tag                     |

Workflow triggers:

- **Tag push** (`v*`): automatic full build and GitHub Release creation
- **Manual dispatch**: select target (all / linux-only / mac-only)

C dependency builds are cached per platform to avoid redundant compilation.

## RAPT 16K Page Alignment

The `patches/rapt/0001-*` patch adds the `-Wl,-z,max-page-size=16384` linker flag,
ensuring all `.so` files meet Google Play's 16K page alignment requirement.
Alignment is automatically verified via `readelf` during the build.

## Dependency Versions

| Component   | Version             | Source                   |
| ----------- | ------------------- | ------------------------ |
| Ren'Py      | 7.3.5.606           | source build             |
| Python      | 2.7.10              | renpy-deps/source/       |
| SDL2        | 2.0.4               | renpy-deps/source/       |
| FFmpeg      | 3.0                 | renpy-deps/source/       |
| FreeType    | 2.4.11              | renpy-deps/source/       |
| GLEW        | 1.7.0               | renpy-deps/source/       |
| Cython      | 0.29.36             | pip (RAPT cross-compile) |
| Android NDK | r19c (19.2.5345600) | sdkmanager               |
