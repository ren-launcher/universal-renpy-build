# ============================================================================
# Universal Ren'Py Build System
# Build Ren'Py SDK and DLC packages by wrapping upstream renpy-build.
#
# Architecture:
#   This Makefile orchestrates the upstream renpy-build system, applying our
#   patches on top. The upstream build.py handles all cross-compilation,
#   dependency builds, and packaging. We add:
#   - Automated source checkout and patching
#   - Distribution packaging (SDK zip/tar, RAPT DLC, renios DLC)
#   - CI-friendly targets
# ============================================================================

include config.env

# ── Paths ──────────────────────────────────────────────────────────────────
ROOT           := $(CURDIR)
WORK           := $(ROOT)/work
BUILD_ROOT     := $(WORK)/renpy-build
RENPY_SRC      := $(BUILD_ROOT)/renpy
PYGAME_SRC     := $(BUILD_ROOT)/pygame_sdl2
TMP            := $(BUILD_ROOT)/tmp
OUTPUT         := $(ROOT)/output
STAMPS         := $(WORK)/.stamps

$(shell mkdir -p $(STAMPS) $(OUTPUT))

# ── Build arguments for renpy-build/build.py ───────────────────────────────
BUILD_ARGS :=

ifneq ($(BUILD_PLATFORMS),)
BUILD_ARGS += --platform $(BUILD_PLATFORMS)
endif
ifneq ($(BUILD_ARCHS),)
BUILD_ARGS += --arch $(BUILD_ARCHS)
endif
ifneq ($(BUILD_PYTHONS),)
BUILD_ARGS += --python $(BUILD_PYTHONS)
endif

# ── Platform-arch combinations (derived from config.env) ───────────────────
# Used for Live2D stub header installation. Dynamically computed from
# BUILD_PLATFORMS and BUILD_ARCHS to avoid hardcoding.
ALL_PLATFORM_ARCHS := $(shell python3 -c "v={'linux':['x86_64','i686','armv7l','aarch64'],'android':['x86_64','arm64_v8a','armeabi_v7a'],'windows':['x86_64','i686'],'mac':['x86_64'],'ios':['arm64','sim-x86_64','sim-arm64']};print(' '.join(p+'-'+a for p in '$(BUILD_PLATFORMS)'.split(',') for a in '$(BUILD_ARCHS)'.split(',') if a in v.get(p,[])))")

# ── Toolchain download list (derived from config.env + BUILD_PLATFORMS) ────
DOWNLOAD_FILES :=
ifneq ($(findstring android,$(BUILD_PLATFORMS)),)
DOWNLOAD_FILES += $(TARS_ANDROID)
endif
ifneq ($(findstring linux,$(BUILD_PLATFORMS)),)
DOWNLOAD_FILES += $(TARS_LINUX)
endif

DOWNLOAD_TARGETS := $(addprefix $(BUILD_ROOT)/tars/,$(DOWNLOAD_FILES))

# ── Phony targets ──────────────────────────────────────────────────────────
.PHONY: all build dist dist-rapt rebuild clean clean-build help \
        clone patch prepare

# Default target
all: build dist ## Full build: deps + modules + distribution

help: ## Show available targets
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

# ============================================================================
# Stage 1: Clone source repositories
# ============================================================================

$(STAMPS)/cloned-renpy-build:
	@echo "==> Cloning renpy-build ($(RENPY_BUILD_TAG))..."
	@if [ -d "$(BUILD_ROOT)/.git" ]; then \
		cd $(BUILD_ROOT) && git fetch --tags && git checkout $(RENPY_BUILD_TAG); \
	else \
		git clone $(RENPY_BUILD_REPO) $(BUILD_ROOT) && \
		cd $(BUILD_ROOT) && git checkout $(RENPY_BUILD_TAG); \
	fi
	@touch $@

$(STAMPS)/cloned-renpy: $(STAMPS)/cloned-renpy-build
	@echo "==> Cloning renpy ($(RENPY_TAG))..."
	@if [ -d "$(RENPY_SRC)/.git" ]; then \
		cd $(RENPY_SRC) && git fetch --tags && git checkout $(RENPY_TAG); \
	else \
		git clone --depth 50 --branch $(RENPY_TAG) $(RENPY_REPO) $(RENPY_SRC); \
	fi
	@touch $@

$(STAMPS)/cloned-pygame: $(STAMPS)/cloned-renpy-build
	@echo "==> Cloning pygame_sdl2 ($(PYGAME_SDL2_TAG))..."
	@if [ -d "$(PYGAME_SRC)/.git" ]; then \
		cd $(PYGAME_SRC) && git fetch --tags && git checkout $(PYGAME_SDL2_TAG); \
	else \
		git clone --depth 50 --branch $(PYGAME_SDL2_TAG) $(PYGAME_SDL2_REPO) $(PYGAME_SRC); \
	fi
	@touch $@

clone: $(STAMPS)/cloned-renpy-build $(STAMPS)/cloned-renpy $(STAMPS)/cloned-pygame ## Clone all source repos

# ============================================================================
# Stage 2: Apply patches
# ============================================================================

$(STAMPS)/patched-renpy-build: $(STAMPS)/cloned-renpy-build $(wildcard patches/renpy-build/*.patch)
	@echo "==> Applying renpy-build patches..."
	@cd $(BUILD_ROOT) && git checkout $(RENPY_BUILD_TAG) -- . 2>/dev/null || true
	@if ls patches/renpy-build/*.patch 1>/dev/null 2>&1; then \
		cd $(BUILD_ROOT) && \
		set -e; \
		for p in $(ROOT)/patches/renpy-build/*.patch; do \
			echo "    Applying $$(basename $$p)"; \
			git apply "$$p"; \
		done; \
	fi
	@touch $@

$(STAMPS)/patched-renpy: $(STAMPS)/cloned-renpy $(wildcard patches/renpy/*.patch)
	@echo "==> Applying renpy patches..."
	@cd $(RENPY_SRC) && git checkout $(RENPY_TAG) -- . 2>/dev/null || true
	@if ls patches/renpy/*.patch 1>/dev/null 2>&1; then \
		cd $(RENPY_SRC) && \
		set -e; \
		for p in $(ROOT)/patches/renpy/*.patch; do \
			echo "    Applying $$(basename $$p)"; \
			git apply "$$p"; \
		done; \
	fi
	@touch $@

$(STAMPS)/patched-pygame: $(STAMPS)/cloned-pygame $(wildcard patches/pygame_sdl2/*.patch)
	@echo "==> Applying pygame_sdl2 patches..."
	@cd $(PYGAME_SRC) && git checkout $(PYGAME_SDL2_TAG) -- . 2>/dev/null || true
	@if ls patches/pygame_sdl2/*.patch 1>/dev/null 2>&1; then \
		cd $(PYGAME_SRC) && \
		set -e; \
		for p in $(ROOT)/patches/pygame_sdl2/*.patch; do \
			echo "    Applying $$(basename $$p)"; \
			git apply "$$p"; \
		done; \
	fi
	@touch $@

patch: $(STAMPS)/patched-renpy-build $(STAMPS)/patched-renpy $(STAMPS)/patched-pygame ## Apply all patches

# ============================================================================
# Stage 3: Prepare build environment (tarballs + upstream prepare)
# ============================================================================

# Pattern rule: download any tarball using its URL.<filename> variable.
$(BUILD_ROOT)/tars/%:
	@mkdir -p $(dir $@)
	@echo "  [dl] $*"
	@curl -fSL --retry 3 --retry-delay 5 -o $@.tmp "$(URL.$*)" && mv $@.tmp $@

$(STAMPS)/prepared: $(STAMPS)/cloned-renpy-build $(STAMPS)/patched-renpy-build $(STAMPS)/patched-pygame $(STAMPS)/patched-renpy $(DOWNLOAD_TARGETS)
	@echo "==> Installing dependencies via upstream prepare.sh (requires sudo)..."
	@cd $(BUILD_ROOT) && bash ./prepare.sh
	@touch $@

prepare: $(STAMPS)/prepared ## Install deps and download tarballs via upstream prepare

# ============================================================================
# Stage 4: Build everything via renpy-build
# ============================================================================

$(STAMPS)/built: $(STAMPS)/prepared $(STAMPS)/patched-renpy-build $(STAMPS)/patched-renpy $(STAMPS)/patched-pygame
	@echo "==> Preparing Live2D Cubism stub header..."
	@for pa in $(ALL_PLATFORM_ARCHS); do \
		mkdir -p "$(TMP)/install.$$pa/cubism/Core/include"; \
		cp -n "$(ROOT)/stubs/Live2DCubismCore.h" \
		      "$(TMP)/install.$$pa/cubism/Core/include/" 2>/dev/null || true; \
	done
	@echo "==> Running renpy-build build.sh..."
	cd $(BUILD_ROOT) && bash build.sh $(BUILD_ARGS) build
	@touch $@

build: $(STAMPS)/built ## Build all C deps + modules via renpy-build

# ============================================================================
# Stage 5: Distribution packaging
# ============================================================================

dist: $(STAMPS)/built ## Package SDK + DLCs
	@echo "==> Building distribution..."
	$(ROOT)/scripts/distribute.sh \
		"$(RENPY_SRC)" "$(PYGAME_SRC)" "$(BUILD_ROOT)" "$(TMP)" \
		"$(RENPY_VERSION)" "$(RENPY_TAG)" \
		"$(OUTPUT)"

# ============================================================================
# RAPT DLC — package only (requires full build for linux-x86_64 runtime)
# ============================================================================

dist-rapt: $(STAMPS)/built ## Package RAPT DLC (requires build first)
	@echo "==> Packaging RAPT DLC..."
	$(ROOT)/scripts/distribute-rapt.sh \
		"$(RENPY_SRC)" "$(PYGAME_SRC)" "$(BUILD_ROOT)" "$(TMP)" \
		"$(RENPY_VERSION)" "$(RENPY_TAG)" \
		"$(OUTPUT)"

# ============================================================================
# Rebuild specific tasks (pass TASKS="taskname")
# ============================================================================

TASKS ?=
rebuild: patch ## Rebuild specific tasks: make rebuild TASKS="renpython librenpy"
	@for pa in $(ALL_PLATFORM_ARCHS); do \
		mkdir -p "$(TMP)/install.$$pa/cubism/Core/include"; \
		cp -n "$(ROOT)/stubs/Live2DCubismCore.h" \
		      "$(TMP)/install.$$pa/cubism/Core/include/" 2>/dev/null || true; \
	done
	cd $(BUILD_ROOT) && bash build.sh $(BUILD_ARGS) rebuild $(TASKS)

# ============================================================================
# Utility targets
# ============================================================================

clean-build: ## Remove build artifacts (keeps source clones)
	rm -rf $(TMP)
	rm -f $(STAMPS)/built $(STAMPS)/tars

clean: ## Remove everything
	rm -rf $(WORK) $(OUTPUT)
