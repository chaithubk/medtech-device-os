# Build Guide

Complete instructions for building MedTech Device OS from source.

---

## Table of Contents

- [Overview](#overview)
- [Dev Container (recommended)](#dev-container-recommended)
- [Manual Setup (advanced)](#manual-setup-advanced)
- [Build Targets](#build-targets)
- [Build Options and Customization](#build-options-and-customization)
- [Output Artifacts](#output-artifacts)
- [Post-Build Steps](#post-build-steps)
- [Incremental Builds](#incremental-builds)
- [Build Troubleshooting](#build-troubleshooting)

---

## Overview

MedTech Device OS uses the [Yocto Project](https://www.yoctoproject.org/) build system (kirkstone release)
to produce an embedded Linux image for ARM64 (`qemuarm64` machine).

The build requires:
- Ubuntu 22.04 host (or the provided dev container)
- ~30 GB disk space for the full build
- ~4–8 GB RAM
- Multi-core CPU (builds are parallelized)

> **Recommended:** Use the dev container path. It provides an isolated,
> reproducible build environment without installing Yocto host tools on your
> workstation.

---

## Dev Container (recommended)

### Prerequisites

- VS Code with Dev Containers extension
- Docker Desktop (or Docker Engine)

### Steps

1. **Open the repository in VS Code** and reopen in the dev container:
   ```
   Ctrl+Shift+P → Dev Containers: Reopen in Container
   ```

2. **Wait for setup to complete** — `postCreateCommand` runs `quick-setup.sh`
   which clones Yocto layers and initializes the build configuration.

3. **Build:**
   ```bash
   bitbake core-image-medtech
   ```

The `bitbake` command in the container is a wrapper script (`scripts/bitbake`)
that handles all environment setup automatically. See [QUICK_START_DEVELOPER.md](QUICK_START_DEVELOPER.md)
for details.

---

## Manual Setup (advanced)

If you prefer not to use a dev container, or are setting up CI manually:

### 1. Install host tools

```bash
sudo apt-get update
sudo apt-get install -y \
  gawk wget git diffstat unzip texinfo gcc g++ build-essential \
  chrpath socat cpio python3 python3-pip python3-pexpect \
  xz-utils debianutils iputils-ping curl file locales \
  autoconf automake libtool pkg-config gettext \
  patch perl bison flex gperf
```

### 2. Create non-root build user

BitBake refuses to run as root:
```bash
useradd -m builder
chown -R builder:builder /workspace
```

### 3. Clone Yocto layers

```bash
cd yocto
git clone -b kirkstone --depth 1 https://git.yoctoproject.org/git/poky poky
git clone -b kirkstone --depth 1 https://github.com/openembedded/meta-openembedded.git meta-openembedded
git clone -b 6.4 --depth 1 https://code.qt.io/yocto/meta-qt6.git meta-qt6
```

### 4. Initialize build environment

```bash
su - builder -c "
  cd /workspace/yocto
  source poky/oe-init-build-env build
  cp ../conf/local.conf.sample conf/local.conf
  cp ../conf/bblayers.conf.sample conf/bblayers.conf
"
```

### 5. Build

```bash
su - builder -c "
  cd /workspace/yocto
  source poky/oe-init-build-env build
  bitbake core-image-medtech
"
```

---

## Build Targets

### `core-image-medtech` (production image)

The full MedTech Device OS image with all services:
- Mosquitto MQTT broker
- Vitals publisher (Python)
- Edge analytics (TensorFlow Lite)
- Clinician UI (Qt6)

```bash
bitbake core-image-medtech
```

**Output:** `yocto/build/tmp/deploy/images/qemuarm64/core-image-medtech-qemuarm64.ext4`

### `core-image-minimal` (CI sanity check)

A lightweight minimal image used by CI for pull request validation. Does not
include medtech-specific services.

```bash
bitbake core-image-minimal
```

### Individual recipes

```bash
# Build and test one service
bitbake medtech-vitals-publisher
bitbake medtech-edge-analytics
bitbake medtech-clinician-ui

# Build the MQTT broker
bitbake mosquitto

# Build the base system package
bitbake medtech-system
```

---

## Build Options and Customization

### Key variables in `local.conf`

Located at `yocto/build/conf/local.conf` (generated from `yocto/conf/local.conf.sample`):

| Variable | Purpose | Default |
|---|---|---|
| `MACHINE` | Target hardware | `qemuarm64` |
| `DISTRO` | Yocto distribution | `poky` |
| `IMAGE_ROOTFS_SIZE` | Root filesystem size (kB) | `524288` (512 MB) |
| `BB_NUMBER_THREADS` | BitBake parallel tasks | Auto (CPU count) |
| `PARALLEL_MAKE` | `make` parallelism | Auto |
| `RM_WORK` | Delete work dirs after build | `1` |
| `INHERIT += "rm_work"` | Enables work dir cleanup | Enabled in CI |

### Useful debug flags

```bash
# Verbose BitBake output
bitbake -v core-image-medtech

# Show task graph for a recipe
bitbake -g medtech-vitals-publisher
# Generates: task-depends.dot (visualize with dot/graphviz)

# Show all variables for a recipe
bitbake -e medtech-vitals-publisher

# List all tasks for a recipe
bitbake -c listtasks medtech-vitals-publisher
```

---

## Output Artifacts

After a successful build, artifacts are in:

```
yocto/build/tmp/deploy/images/qemuarm64/
├── core-image-medtech-qemuarm64.ext4          # Root filesystem
├── core-image-medtech-qemuarm64.manifest      # Package list
├── Image-qemuarm64.bin                        # Kernel image
└── core-image-medtech-qemuarm64.qemuboot.conf # QEMU boot config
```

---

## Post-Build Steps

### Boot the image

```bash
bash scripts/run-qemu.sh
```

### Package for distribution

```bash
bash scripts/package-release-artifacts.sh --image-name core-image-medtech
# Output: artifacts/core-image-medtech-qemuarm64-bundle.tar.gz
```

### Verify the package

```bash
bash scripts/verify-release-package.sh --image-name core-image-medtech
```

### Generate SBOM

```bash
bash scripts/generate-sbom.sh
# Output: sbom/sbom.json (CycloneDX 1.4 format)
```

### Run image policy checks

```bash
bash scripts/verify-image.sh python-sanity
```

---

## Incremental Builds

Yocto uses shared-state cache (sstate-cache) to avoid rebuilding unchanged recipes.
After the first full build, most subsequent builds will reuse cached results.

### What triggers a rebuild

- Changing a recipe file (`.bb` or `.bbappend`)
- Changing recipe source files (the `SRC_URI` content)
- Changing `local.conf` or `bblayers.conf`
- Changing a `DISTRO_FEATURES` or `IMAGE_INSTALL` variable

### Force rebuild of a single recipe

```bash
bitbake -c cleansstate medtech-vitals-publisher
bitbake medtech-vitals-publisher
```

### Rebuild only what changed (default behavior)

```bash
bitbake core-image-medtech
# BitBake automatically rebuilds only changed recipes
```

---

## Build Troubleshooting

### Common errors

**"Nothing PROVIDES ..." or provider resolution failure:**
```bash
# Re-parse metadata
bitbake -p

# Check available providers
bitbake -e core-image-medtech | grep ^PREFERRED_PROVIDER
```

**Fetch failure (network/checksum):**
```bash
# Clear download cache and retry
bitbake -c cleanall medtech-vitals-publisher
bitbake medtech-vitals-publisher
```

**Out of disk space during build:**
```bash
# Check space
df -h /

# Clean work directories (safe to remove)
rm -rf yocto/build/tmp/work/
rm -rf yocto/build/tmp/work-shared/

# See docs/DISK_OPTIMIZATION.md for full strategy
```

**Task failure — read the log:**
```bash
# Check the last build log
cat yocto/build/tmp/work/*/medtech-vitals-publisher/*/temp/log.do_compile
```

See [yocto-ci-failure-detection.md](yocto-ci-failure-detection.md) for the full
CI-first triage runbook.
