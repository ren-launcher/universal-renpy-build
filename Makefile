# ============================================================================
# Universal Ren'Py Build System
# Build Ren'Py 7.3.5 SDK and DLC packages entirely from source.
# Supports Linux x86_64 and macOS x86_64 (multi-platform via CI merge).
# ============================================================================

include config.env

# ── Platform detection ─────────────────────────────────────────────────────
UNAME_S      := $(shell uname -s)
UNAME_M      := $(shell uname -m)

ifeq ($(UNAME_S),Darwin)
  PLATFORM   := darwin-x86_64
else
  PLATFORM   := linux-$(UNAME_M)
endif

# ── Paths ──────────────────────────────────────────────────────────────────
ROOT         := $(CURDIR)
WORK         := $(ROOT)/work
RENPY_DEPS   := $(WORK)/renpy-deps
RENPY_ROOT   := $(WORK)/renpy
PYGAME_ROOT  := $(WORK)/pygame_sdl2
RAPT_ROOT    := $(WORK)/rapt
RENIOS_ROOT  := $(WORK)/renios
DEPS_BUILD   := $(WORK)/$(PLATFORM)-deps
OUTPUT       := $(ROOT)/output

# Android SDK/NDK (Linux only, for RAPT)
ANDROID_HOME ?= $(HOME)/Android/Sdk
ANDROID_NDK  := $(ANDROID_HOME)/ndk/$(ANDROID_NDK_VERSION)

# Python 2 virtualenv (provides `python` command for renpy-deps build scripts)
PY2_VENV     := $(WORK)/py2-venv
ACTIVATE_PY2  = . $(PY2_VENV)/bin/activate &&

# Makefile internal stamp dir
STAMPS       := $(WORK)/.stamps
$(shell mkdir -p $(STAMPS) $(OUTPUT))

# ── Phony targets ──────────────────────────────────────────────────────────
.PHONY: all sdk dist-rapt dist-renios lib-only merge-libs \
        rapt-native renios-native \
        clean clean-deps clean-rapt help

# Default: build everything appropriate for the current platform
ifeq ($(UNAME_S),Darwin)
all: sdk dist-renios ## Build SDK + platform DLCs
else
all: sdk dist-rapt
endif

help: ## Show available targets
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

# ============================================================================
# Stage 1: Clone source repositories
# ============================================================================

$(STAMPS)/cloned: | $(STAMPS)
	@echo "==> Cloning source repositories..."
	git clone --depth 1 --branch $(RENPY_TAG) $(RENPY_REPO) $(RENPY_ROOT) 2>/dev/null || true
	git clone --depth 1 --branch $(RAPT_TAG) $(RAPT_REPO) $(RAPT_ROOT) 2>/dev/null || true
	git clone --depth 1 --branch $(PYGAME_SDL2_TAG) $(PYGAME_SDL2_REPO) $(PYGAME_ROOT) 2>/dev/null || true
	git clone --depth 1 --branch $(RENPY_DEPS_TAG) $(RENPY_DEPS_REPO) $(RENPY_DEPS) 2>/dev/null || true
	git clone --depth 1 --branch $(RENIOS_TAG) $(RENIOS_REPO) $(RENIOS_ROOT) 2>/dev/null || true
	@touch $@

# ============================================================================
# Stage 2: Apply patches (all upstream modifications recorded as patches)
# ============================================================================

$(STAMPS)/patched-renpy: $(wildcard patches/renpy/*.patch) $(STAMPS)/cloned
	@echo "==> Applying Ren'Py patches..."
	cd $(RENPY_ROOT) && git reset --hard $(RENPY_TAG) && \
	  git apply $(ROOT)/patches/renpy/*.patch
	@touch $@

$(STAMPS)/patched-rapt: $(wildcard patches/rapt/*.patch) $(STAMPS)/cloned
	@echo "==> Applying RAPT patches..."
	cd $(RAPT_ROOT) && git reset --hard $(RAPT_TAG) && \
	  git apply $(ROOT)/patches/rapt/*.patch
	@touch $@

$(STAMPS)/patched-renios: $(wildcard patches/renios/*.patch) $(STAMPS)/cloned
	@echo "==> Applying renios patches..."
	cd $(RENIOS_ROOT) && git reset --hard $(RENIOS_TAG) && \
	  git apply $(ROOT)/patches/renios/*.patch
	@touch $@

$(STAMPS)/patched-renpy-deps: $(wildcard patches/renpy-deps/*.patch) $(STAMPS)/cloned
	@echo "==> Applying renpy-deps patches..."
	cd $(RENPY_DEPS) && git reset --hard $(RENPY_DEPS_TAG) && \
	  git apply $(ROOT)/patches/renpy-deps/*.patch
	@touch $@

# ============================================================================
# Stage 3: Build C dependencies via renpy-deps
#   Linux: build_python.sh + build.sh  (with PKG_CONFIG_PATH fix)
#   macOS: build_mac.sh (wraps both with MACOSX_DEPLOYMENT_TARGET=10.9)
# ============================================================================

$(STAMPS)/deps: $(STAMPS)/patched-renpy-deps
	@echo "==> Building C dependencies for $(PLATFORM)..."
	mkdir -p $(DEPS_BUILD)
ifeq ($(UNAME_S),Darwin)
  ifeq ($(UNAME_M),arm64)
	@echo "==> Building under Rosetta 2 (x86_64) for Apple Silicon..."
	cd $(DEPS_BUILD) && $(ACTIVATE_PY2) /usr/bin/arch -x86_64 bash $(RENPY_DEPS)/build_mac.sh
  else
	cd $(DEPS_BUILD) && $(ACTIVATE_PY2) bash $(RENPY_DEPS)/build_mac.sh
  endif
else
	cd $(DEPS_BUILD) && bash $(RENPY_DEPS)/build_python.sh
	cd $(DEPS_BUILD) && export PKG_CONFIG_PATH="$(DEPS_BUILD)/install/lib/pkgconfig:$$PKG_CONFIG_PATH" && \
	  bash $(RENPY_DEPS)/build.sh
endif
	@touch $@

# ============================================================================
# Stage 4: Build pygame_sdl2 + Ren'Py C extension modules
# ============================================================================

$(STAMPS)/modules: $(STAMPS)/deps $(STAMPS)/patched-renpy
	@echo "==> Bootstrapping pip in deps Python..."
	. $(DEPS_BUILD)/env.sh && \
	  python -m ensurepip 2>/dev/null || true
	@echo "==> Installing Cython into deps Python..."
	. $(DEPS_BUILD)/env.sh && \
	  python -m pip install --no-build-isolation "Cython==$(CYTHON_VERSION)" 2>/dev/null || \
	  ( echo "==> Downloading Cython wheel via system Python (SSL fallback)..." && \
	    $(ACTIVATE_PY2) pip download --no-deps --dest /tmp/cython-wheel \
	      "Cython==$(CYTHON_VERSION)" && \
	    . $(DEPS_BUILD)/env.sh && \
	    python -m pip install --no-index --find-links /tmp/cython-wheel \
	      "Cython==$(CYTHON_VERSION)" )
	@echo "==> Building pygame_sdl2..."
	. $(DEPS_BUILD)/env.sh && \
	  export PYGAME_SDL2_INSTALL_HEADERS=1 && \
	  cd $(PYGAME_ROOT) && \
	  python setup.py clean --all && \
	  python setup.py install_lib -d $$PYTHONPATH && \
	  python setup.py install_headers -d $(DEPS_BUILD)/install/include/pygame_sdl2
	@echo "==> Building Ren'Py C modules..."
	. $(DEPS_BUILD)/env.sh && \
	  cd $(RENPY_ROOT)/module && \
	  python setup.py clean --all && \
	  python setup.py install_lib -d $$PYTHONPATH
	@touch $@

# ============================================================================
# Stage 5: Package lib/<platform> directory via PyInstaller (renpython)
# ============================================================================

$(STAMPS)/lib: $(STAMPS)/modules
	@echo "==> Packaging lib/$(PLATFORM) via renpython..."
	. $(DEPS_BUILD)/env.sh && \
	  cd $(RENPY_DEPS)/renpython && \
	  python -O build.py $(PLATFORM) $(RENPY_ROOT) renpy.py && \
	  python -O merge.py $(RENPY_ROOT) $(PLATFORM)
	@touch $@

lib-only: $(STAMPS)/lib ## Build lib/<platform> only (for CI per-platform jobs)

# ============================================================================
# Stage 5b: Merge multi-platform libs (CI only)
#   Import lib/ directories from other platform builds into renpy source tree.
#   Usage: make merge-libs EXTRA_LIBS=/path/to/downloaded/libs
#   EXTRA_LIBS directory should contain subdirs like linux-x86_64/, darwin-x86_64/
# ============================================================================

EXTRA_LIBS ?=

merge-libs: $(STAMPS)/lib ## Merge additional platform libs into renpy tree
ifneq ($(EXTRA_LIBS),)
	@if [ -d "$(EXTRA_LIBS)" ]; then \
	  echo "==> Merging additional platform libs from $(EXTRA_LIBS)..."; \
	  for plat_dir in $(EXTRA_LIBS)/*/; do \
	    [ -d "$$plat_dir" ] || continue; \
	    plat=$$(basename "$$plat_dir"); \
	    echo "    Merging lib/$$plat..."; \
	    mkdir -p $(RENPY_ROOT)/lib/$$plat; \
	    cp -a "$$plat_dir"* $(RENPY_ROOT)/lib/$$plat/; \
	  done; \
	else \
	  echo "==> EXTRA_LIBS dir not found, skipping merge."; \
	fi
else
	@echo "==> No EXTRA_LIBS specified, skipping merge."
endif

# ============================================================================
# Stage 6: SDK distribution
# ============================================================================

sdk: merge-libs ## Build Ren'Py SDK zip + tar.bz2
	@echo "==> Building SDK distribution..."
	cd $(RENPY_ROOT) && \
	  printf "vc_version = %s\n" "$$(echo $(RENPY_TAG) | rev | cut -d. -f1 | rev)" \
	    > renpy/vc_version.py && \
	  SDL_VIDEODRIVER=dummy ./renpy.sh launcher quit && \
	  SDL_VIDEODRIVER=dummy ./renpy.sh launcher distribute launcher \
	    --package sdk \
	    --destination $(OUTPUT) \
	    --no-update
	@echo "==> SDK built: $(OUTPUT)/"

# ============================================================================
# Stage 7: RAPT native Android .so build (Linux only)
# ============================================================================

# Cython virtualenv needed by RAPT's cross-compilation
$(STAMPS)/cython-venv:
	@echo "==> Setting up Cython virtualenv..."
	python2 -m virtualenv $(WORK)/cython2-venv 2>/dev/null || \
	  virtualenv -p python2 $(WORK)/cython2-venv
	$(WORK)/cython2-venv/bin/pip install "Cython==$(CYTHON_VERSION)"
	@touch $@

# Install Android NDK via sdkmanager if not present
$(STAMPS)/android-ndk:
	@echo "==> Ensuring Android NDK $(ANDROID_NDK_VERSION) is installed..."
	@if [ ! -d "$(ANDROID_NDK)" ]; then \
	  echo "NDK not found at $(ANDROID_NDK), installing via sdkmanager..."; \
	  yes | "$(ANDROID_HOME)/cmdline-tools/latest/bin/sdkmanager" \
	    "ndk;$(ANDROID_NDK_VERSION)" \
	    "build-tools;$(ANDROID_BUILD_TOOLS)" \
	    "platforms;$(ANDROID_PLATFORM)" || true; \
	else \
	  echo "NDK already installed at $(ANDROID_NDK)"; \
	fi
	@test -d "$(ANDROID_NDK)" || { echo "ERROR: NDK installation failed"; exit 1; }
	@touch $@

$(STAMPS)/rapt-native: $(STAMPS)/patched-rapt $(STAMPS)/cython-venv $(STAMPS)/android-ndk
	@echo "==> Building RAPT native libraries..."
	export PATH="$(WORK)/cython2-venv/bin:$$PATH" && \
	  export PYGAME_SDL2_ROOT=$(PYGAME_ROOT) && \
	  export RENPY_ROOT=$(RENPY_ROOT) && \
	  export ANDROID_HOME=$(ANDROID_HOME) && \
	  export ANDROID_NDK=$(ANDROID_NDK) && \
	  cd $(RAPT_ROOT)/native && bash build.sh ""
	@echo "==> Verifying 16K page alignment..."
	@fail=0; \
	for so in $$(find $(RAPT_ROOT)/project -name '*.so' -path '*/jniLibs/*'); do \
	  align=$$(readelf -lW "$$so" 2>/dev/null | awk '/LOAD/{print $$NF}' | head -1); \
	  if [ "$$align" != "0x4000" ]; then \
	    echo "FAIL: $$so (align=$$align)"; fail=1; \
	  fi; \
	done; \
	[ $$fail -eq 0 ] && echo "All .so files are 16K aligned." || exit 1
	@touch $@

# ============================================================================
# Stage 8: RAPT DLC distribution
# ============================================================================

dist-rapt: $(STAMPS)/rapt-native merge-libs ## Build RAPT DLC zip
	@echo "==> Preparing RAPT for distribution..."
	mkdir -p $(RENPY_ROOT)/rapt
	cp -a $(RAPT_ROOT)/android.py $(RENPY_ROOT)/rapt/
	cp -a $(RAPT_ROOT)/buildlib $(RENPY_ROOT)/rapt/
	cp -a $(RAPT_ROOT)/templates $(RENPY_ROOT)/rapt/
	cp -a $(RAPT_ROOT)/project $(RENPY_ROOT)/rapt/prototype
	# Compile rapt buildlib .pyc
	. $(DEPS_BUILD)/env.sh && \
	  python -m compileall $(RENPY_ROOT)/rapt/buildlib/
	@echo "==> Building RAPT DLC distribution..."
	cd $(RENPY_ROOT) && \
	  printf "vc_version = %s\n" "$$(echo $(RENPY_TAG) | rev | cut -d. -f1 | rev)" \
	    > renpy/vc_version.py && \
	  SDL_VIDEODRIVER=dummy ./renpy.sh launcher quit && \
	  SDL_VIDEODRIVER=dummy ./renpy.sh launcher distribute launcher \
	    --package rapt \
	    --destination $(OUTPUT) \
	    --no-update
	@echo "==> RAPT DLC built: $(OUTPUT)/"

# ============================================================================
# Stage 9: renios (iOS) native build (macOS only)
#   Builds Python + SDL2 + FFmpeg etc. for iOS/Simulator via Xcode toolchain.
# ============================================================================

$(STAMPS)/renios-native: $(STAMPS)/patched-renios $(STAMPS)/patched-renpy
ifeq ($(UNAME_S),Darwin)
	@echo "==> Building renios native libraries..."
	export XCODEAPP=$$(xcode-select -p | sed 's|/Contents/Developer||') && \
	  export RENPY_ROOT=$(RENPY_ROOT) && \
	  export PYGAME_SDL2_ROOT=$(PYGAME_ROOT) && \
	  export PY2_VENV=$(PY2_VENV) && \
	  export PATH="$(PY2_VENV)/bin:$$PATH" && \
	  cd $(RENIOS_ROOT) && bash build_all.sh
else
	@echo "SKIP: renios native build requires macOS with Xcode."
endif
	@touch $@

# ============================================================================
# Stage 10: renios DLC distribution (macOS only)
# ============================================================================

dist-renios: $(STAMPS)/renios-native merge-libs ## Build renios DLC zip (macOS only)
ifeq ($(UNAME_S),Darwin)
	@echo "==> Preparing renios for distribution..."
	mkdir -p $(RENPY_ROOT)/renios
	cp -a $(RENIOS_ROOT)/ios.py $(RENPY_ROOT)/renios/
	cp -a $(RENIOS_ROOT)/buildlib $(RENPY_ROOT)/renios/
	cp -a $(RENIOS_ROOT)/prototype $(RENPY_ROOT)/renios/prototype
	# Create version.txt
	echo "$(RENPY_VERSION)" > $(RENPY_ROOT)/renios/version.txt
	# Compile renios buildlib .pyc
	. $(DEPS_BUILD)/env.sh && \
	  python -m compileall $(RENPY_ROOT)/renios/buildlib/
	@echo "==> Building renios DLC distribution..."
	cd $(RENPY_ROOT) && \
	  printf "vc_version = %s\n" "$$(echo $(RENPY_TAG) | rev | cut -d. -f1 | rev)" \
	    > renpy/vc_version.py && \
	  SDL_VIDEODRIVER=dummy ./renpy.sh launcher quit && \
	  SDL_VIDEODRIVER=dummy ./renpy.sh launcher distribute launcher \
	    --package renios \
	    --destination $(OUTPUT) \
	    --no-update
	@echo "==> renios DLC built: $(OUTPUT)/"
else
	@echo "SKIP: renios DLC requires macOS. Run on macOS runner."
endif

# ── Convenience phony targets for CI ───────────────────────────────────────

rapt-native: $(STAMPS)/rapt-native ## Build RAPT native .so only (no packaging)

renios-native: $(STAMPS)/renios-native ## Build renios native libs only (no packaging)

# ============================================================================
# Clean targets
# ============================================================================

clean: ## Remove all build artifacts
	rm -rf $(WORK) $(OUTPUT)

clean-deps: ## Remove only C dependency build (keeps clones)
	rm -rf $(DEPS_BUILD) $(STAMPS)/deps $(STAMPS)/modules $(STAMPS)/lib

clean-rapt: ## Remove RAPT build artifacts
	rm -rf $(RAPT_ROOT)/native/build $(STAMPS)/rapt-native
