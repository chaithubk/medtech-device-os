# Disk Space Optimization Strategy

## Problem

GitHub Actions runners have limited disk space (~14 GB available after OS). Yocto builds can easily exceed this, especially when building:
- GCC toolchain and SDK
- Debug symbols for all packages
- Development packages (-dev, -staticdev)
- Documentation
- Source code archives for SPDX

This document explains the optimizations applied to keep builds within disk constraints.

---

## Solution Overview

### 1. **Image Recipe Optimization** (`core-image-medtech.bb`)

**Removed packages:**
- ❌ `python3` (meta-package) → use `python3-core` instead
- ❌ `python3-pip` → not needed on device (packages pre-built)
- ❌ `openssh-ssh` → `openssh` already includes client
- ❌ `wget` → `curl` is sufficient
- ❌ `nano` → not needed in production image
- ❌ `htop` → not needed in production image
- ❌ `rsyslog` → systemd journal is sufficient
- ❌ `mesa` → not needed for Qt offscreen backend

**Result:** ~200-300 MB saved in rootfs, ~500 MB-1 GB saved in build artifacts

---

### 2. **Build Configuration** (`local.conf.sample`)

#### **Disable SDK builds**
```bitbake
SDKMACHINE = ""
```
Prevents building cross-compilation SDK (~2-3 GB saved)

#### **Strip debug symbols**
```bitbake
INHIBIT_PACKAGE_DEBUG_SPLIT = "1"
```
Prevents creation of separate `-dbg` packages (~1-2 GB saved)

#### **Remove API documentation**
```bitbake
DISTRO_FEATURES:remove = "api-documentation"
```
Skips building man pages, API docs (~200-500 MB saved)

#### **Disable SPDX source inclusion**
```bitbake
SPDX_INCLUDE_SOURCES = "0"
```
SPDX SBOM doesn't embed source archives (~500 MB-1 GB saved)

#### **Optional: rm_work class**
```bitbake
# INHERIT += "rm_work"
# RM_WORK_EXCLUDE += "core-image-medtech"
```
Automatically deletes build artifacts after each recipe completes. **Use only as last resort** — breaks incremental builds and debugging.

---

### 3. **CI/CD Workflow** (`device-build-smart.yml`)

#### **Pre-build disk cleanup**
```bash
sudo rm -rf /usr/share/dotnet      # ~2 GB
sudo rm -rf /usr/local/lib/android # ~8 GB
sudo rm -rf /opt/ghc               # ~1-2 GB
sudo rm -rf /opt/hostedtoolcache/CodeQL # ~1-2 GB
sudo docker image prune -af        # ~1-2 GB
```

**Result:** ~12-15 GB freed before build starts

#### **Smart caching**
- `sstate-cache` and `downloads` are cached between runs
- Cache key based on recipe content SHA → invalidates when recipes change
- Incremental builds reuse ~80-90% of previous build artifacts

---

## Disk Space Budget (GitHub Actions)

| Component | Before Optimization | After Optimization |
|-----------|--------------------:|-------------------:|
| GitHub runner base | 14 GB available | 14 GB available |
| Pre-build cleanup | 0 GB freed | **+12 GB freed** |
| **Available for build** | **14 GB** | **26 GB** |
| Yocto `tmp/` directory | ~12-15 GB | ~8-10 GB |
| `downloads/` cache | ~2-3 GB | ~2-3 GB |
| `sstate-cache/` | ~8-10 GB | ~8-10 GB |
| **Total used** | **~22-28 GB** ❌ | **~18-23 GB** ✅ |

---

## Verification

### Check disk usage during build
```bash
df -h
du -sh yocto/build/tmp
du -sh yocto/downloads
du -sh yocto/sstate-cache
```

### Verify packages NOT in image
```bash
# Inside QEMU or check manifest:
opkg list-installed | grep -E "(pip|wget|nano|htop|mesa|gcc|gdb)"
# Should return nothing

# Check image size:
ls -lh tmp/deploy/images/qemuarm64/core-image-medtech-qemuarm64.ext4
```

---

## Further Optimization (if still needed)

### 1. **Enable rm_work**
Uncomment in `local.conf.sample`:
```bitbake
INHERIT += "rm_work"
RM_WORK_EXCLUDE += "core-image-medtech"
```
⚠️ **Warning:** Breaks incremental builds and recipe debugging.

### 2. **Reduce parallel jobs**
```bitbake
BB_NUMBER_THREADS = "2"
PARALLEL_MAKE = "-j 2"
```
Trades build speed for lower peak disk usage.

### 3. **Use hosted build server**
Consider self-hosted GitHub runner with more disk space (100+ GB).

---

## References

- Yocto Project Optimization Guide: https://docs.yoctoproject.org/singleindex.html#optimization
- GitHub Actions Runner specs: https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners
- BitBake rm_work class: https://docs.yoctoproject.org/ref-manual/classes.html#rm-work-bbclass
