# Scripts Guide

Scripts are organized by purpose and audience.

| Emoji | Category |
|---|---|
| 🚀 | User scripts — for running QEMU images (no build required) |
| 👨‍💻 | Developer scripts — for building inside the dev container |
| 🔧 | CI-internal scripts — used by the GitHub Actions pipeline |

---

## 🚀 User Scripts (run releases, no build)

### `setup-host-qemu-prereqs.sh`

**Prepare a plain Ubuntu host to run QEMU releases. Run once.**

- Installs `qemu-system-aarch64` and related packages
- No Docker required
- Validates the installation after installing

```bash
bash scripts/setup-host-qemu-prereqs.sh

# Only validate (skip install)
bash scripts/setup-host-qemu-prereqs.sh --no-install
```

---

### `download-and-run-qemu.sh`

**Download a GitHub Release and boot it in QEMU. The primary user script.**

- Downloads bundle, manifest, and SHA256SUMS from GitHub Releases
- Verifies SHA256 checksums before extraction
- Boots `qemu-system-aarch64` with SSH forwarded to `localhost:2222`
- **Automatically waits for SSH daemon** (up to 60 seconds, with progress)
- Shows a formatted boot info box with credentials and access methods
- Cleans up the work directory on exit unless `--keep` is set

```bash
# Download and boot the latest release (SSH wait included)
bash scripts/download-and-run-qemu.sh

# Boot a specific release version
bash scripts/download-and-run-qemu.sh --release v1.2.3

# Direct serial console access (interactive terminal, no SSH wait)
bash scripts/download-and-run-qemu.sh --console

# Skip SSH wait (for CI/automation)
bash scripts/download-and-run-qemu.sh --no-wait-ssh

# Boot with more memory
bash scripts/download-and-run-qemu.sh --memory 512

# Keep artifacts after exit
bash scripts/download-and-run-qemu.sh --keep

# Preview QEMU command without booting
bash scripts/download-and-run-qemu.sh --dry-run
```

---

### `inject-ssh-key.sh`

**Inject your SSH public key directly into a release ext4 image (host-side workaround).**

- Useful when you want key-based access without interactive first-boot entry
- Works with extracted release artifacts and local build ext4 images
- Requires Linux host loopback mount support (runs with `sudo` when needed)

```bash
# Inject into a specific extracted release rootfs
bash scripts/inject-ssh-key.sh \
  --rootfs qemu-release/extracted/payload/image/core-image-medtech-qemuarm64-*.rootfs.ext4 \
  --key ~/.ssh/id_medtech.pub

# Auto-detect rootfs and key
bash scripts/inject-ssh-key.sh

# Preview only
bash scripts/inject-ssh-key.sh --dry-run
```

---

### `cleanup-qemu-sessions.sh`

**Minimal helper to stop stale QEMU sessions that hold rootfs image locks.**

```bash
bash scripts/cleanup-qemu-sessions.sh
```

---

## 👨‍💻 Developer Scripts (build inside dev container)

### Canonical Local Build Path

Use this path for day-to-day development inside the dev container:

```bash
bash scripts/quick-setup.sh
bitbake core-image-medtech
```

`bitbake` is a wrapper (`scripts/bitbake`) that always ensures setup is ready.
This is the single recommended build path.

### `bitbake` *(wrapper — transparent setup + optional analysis flags)*

**A transparent wrapper around the real BitBake binary that handles environment setup and enables optional analysis flags.**

**What it does:**
- Detects if the build environment is initialized; runs `quick-setup.sh` if not
- **Automatically drops from root to the `builder` user** (BitBake refuses root builds)
- Sources `oe-init-build-env` before calling the real BitBake
- Preserves all arguments and flags passed to it
- Respects `MEDTECH_ENABLE_*` environment variables for optional analysis

**Basic usage (from any directory in the container):**
```bash
bitbake core-image-medtech
bitbake medtech-vitals-publisher
bitbake -c cleansstate medtech-system && bitbake medtech-system
bitbake -p   # parse only
```

**Enable optional analysis flags via environment variables:**

```bash
# ═══════════════════════════════════════════════════════════════════════════
# OPTION A: Single flag (fastest for one-off analysis)
# ═══════════════════════════════════════════════════════════════════════════
export MEDTECH_ENABLE_BUILDHISTORY=1
bitbake core-image-medtech
# Output: yocto/build/dependency-audit/package-sizes.core-image-medtech.txt
unset MEDTECH_ENABLE_BUILDHISTORY


# ═══════════════════════════════════════════════════════════════════════════
# OPTION B: Multiple flags (for comprehensive audit before GitHub PR)
# ═══════════════════════════════════════════════════════════════════════════
export MEDTECH_ENABLE_BUILDHISTORY=1
export MEDTECH_ENABLE_SPDX=1
export MEDTECH_ENABLE_VIGILES=1

bitbake core-image-medtech

# After build, review all artifacts:
# - SPDX artifacts: yocto/build/tmp/deploy/images/qemuarm64/spdx/
# - Vigiles report: yocto/build/vigiles/core-image-medtech-*-cve.json
# - Package sizes: yocto/build/dependency-audit/package-sizes.core-image-medtech.txt

# Disable when done
unset MEDTECH_ENABLE_BUILDHISTORY MEDTECH_ENABLE_SPDX MEDTECH_ENABLE_VIGILES


# ═══════════════════════════════════════════════════════════════════════════
# COMMON PATTERNS
# ═══════════════════════════════════════════════════════════════════════════

# Quick shell session with flags
bash << 'EOF'
export MEDTECH_ENABLE_SPDX=1
export MEDTECH_ENABLE_BUILDHISTORY=1
bitbake core-image-medtech
unset MEDTECH_ENABLE_SPDX MEDTECH_ENABLE_BUILDHISTORY
EOF

# Multiple builds with same flags
export MEDTECH_ENABLE_BUILDHISTORY=1
bitbake core-image-medtech
bitbake medtech-vitals-publisher
bitbake medtech-clinician-ui
unset MEDTECH_ENABLE_BUILDHISTORY
```

**Available Flags:**

| Flag | Purpose | Build Overhead | Output Location |
|------|---------|-----------------|-----------------|
| `MEDTECH_ENABLE_BUILDHISTORY=1` | Analyze package sizes for bloat detection | ~5% | `dependency-audit/package-sizes.*.txt` |
| `MEDTECH_ENABLE_SPDX=1` | Generate SBOM (Software Bill of Materials) | ~10% | `tmp/deploy/images/*/spdx/` |
| `MEDTECH_ENABLE_VIGILES=1` | Vulnerability scanning (requires API key) | ~15% | `vigiles/core-image-medtech-*-cve.json` |

**Notes:**
- Flags are **disabled by default** in `local.conf.sample` for faster CI builds
- All flags can be set together or individually—they compose independently
- For Vigiles, ensure `VIGILES_KEY_FILE` is set (auto-detected from `.secrets/vigiles-key.txt`)
- `scripts/bitbake` wrapper lives at `scripts/bitbake` and is prepended to PATH in `.devcontainer/devcontainer.json`

---

### `build-robust.sh`

**Production-grade build** with full diagnostics and error recovery.

- Runs pre-flight checks → canonical setup (`quick-setup.sh`) → builds with diagnostics
- Collects disk usage, compiler versions, failed task logs
- Matches CI pipeline behavior
- Suitable for: final validation before CI push, reproducible builds

```bash
bash scripts/build-robust.sh
```

---

### `run-qemu.sh`

**Boot the locally-built image in QEMU** (after `bitbake core-image-medtech`).

- Auto-detects image source from local build output or extracted release payload
- Validates kernel and rootfs image files
- Launches `qemu-system-aarch64` with proper device configuration
- SSH port defaults to `localhost:2222` and auto-falls back when port is busy

```bash
bash scripts/run-qemu.sh           # nographic (terminal console)
bash scripts/run-qemu.sh --graphics  # with GTK display
bash scripts/run-qemu.sh --ssh-port 2244
```

**Inside QEMU:**
```bash
# Login: medadmin via SSH key
systemctl status mosquitto
mosquitto_sub -t "medtech/#" -v
```

**SSH from host:**
```bash
# Use the exact port printed by run-qemu.sh
ssh -p 2222 medadmin@localhost
```

---

### `test-qemu.sh`

**Automated test** — SSHs into a running QEMU instance and verifies services.

- Waits for SSH daemon to start (up to 60 seconds)
- Checks system info, running services, MQTT topics
- Suitable for: validating full boot without manual SSH

```bash
bash scripts/test-qemu.sh
```

---

### `quick-setup.sh`

**Canonical setup script** for local/dev-container builds.

- Runs automatically via `postCreateCommand`
- Ensures `builder` user exists
- Clones/verifies required layers via `clone-with-retry.sh`
- Fixes ownership so builder can read git metadata for all layers
- Initializes and refreshes `yocto/build/conf/*` from samples
- Applies local networking/workaround config snippets idempotently

### Local Vigiles Key (dev container)

CI uses the `VIGILES_KEY_DATA` secret and writes it to a temporary key file.
For local builds, `quick-setup.sh` now bootstraps a local key file template at
`/workspace/.secrets/vigiles-key.txt` automatically.

```bash
# 1) Run setup (automatic in postCreate, safe to re-run)
bash scripts/quick-setup.sh

# 2) Replace placeholder payload with your real key
nano /workspace/.secrets/vigiles-key.txt

# 3) Build normally (wrapper auto-detects key path)
bitbake core-image-medtech
```

Notes:
- `quick-setup.sh` already ensures `INHERIT += "vigiles"` in local config.
- The key file must be a single valid JSON object (no comments), for example:
  `{"email":"you@example.com","key":"YOUR-KEY"}`
- The `scripts/bitbake` wrapper auto-exports `VIGILES_KEY_FILE` when the
  default local file exists and no placeholder remains.
- If you need a non-default key path, export `VIGILES_KEY_FILE` explicitly.

### `clone-with-retry.sh`

Clones Yocto layers with retry logic and mirror fallback. Called by `build-robust.sh`.

---

## Script Inventory (What Is Active)

| Script | Status | Primary Use |
|---|---|---|
| `bitbake` | Active | Canonical build entrypoint wrapper |
| `quick-setup.sh` | Active | Canonical local setup |
| `clone-with-retry.sh` | Active | Layer clone/verification helper |
| `build-robust.sh` | Optional | Full diagnostic build flow |
| `run-qemu.sh` | Active | Boot local built image |
| `test-qemu.sh` | Active | Verify running QEMU instance |
| `setup-host-qemu-prereqs.sh` | Active | Host prep for release users |
| `download-and-run-qemu.sh` | Active | Download+boot release bundle |
| `package-release-artifacts.sh` | Active | CI/local release packaging |
| `verify-release-package.sh` | Active | CI/local release verification |
| `verify-image.sh` | Active | Build policy checks |
| `process-sbom.sh` | Active | Collect SPDX outputs |
| `generate-sbom.sh` | Active (compatibility wrapper) | Delegate to `process-sbom.sh` |
| `audit-image-deps.sh` | Active | Dependency closure analysis |
| `preflight-check.sh` | Active | Tooling/system preflight checks |

---

## 🔧 CI-Internal Scripts

### `package-release-artifacts.sh`

**Package Yocto build outputs into a release bundle.** Used by CI to create the
GitHub Release assets.

- Stages kernel, rootfs, DTBs, SBOM, and manifest into a structured tarball
- Generates a JSON manifest with per-file SHA256 checksums
- Produces SHA256SUMS for bundle and manifest integrity

```bash
bash scripts/package-release-artifacts.sh --image-name core-image-medtech
# Output: artifacts/core-image-medtech-qemuarm64-bundle.tar.gz
#         artifacts/core-image-medtech-qemuarm64-manifest.json
#         artifacts/SHA256SUMS
```

---

### `verify-release-package.sh`

**Verify the integrity of a packaged release bundle.** Used by CI after packaging.

- Verifies SHA256 checksums of bundle and manifest
- Confirms archive contains required payload files (rootfs, manifest)

```bash
bash scripts/verify-release-package.sh --image-name core-image-medtech
```

---

### `preflight-check.sh`

Validates host tools and prerequisites. Called by `build-robust.sh`.

### `generate-sbom.sh`

Compatibility wrapper for SPDX processing.

This script is deprecated as a standalone generator and now delegates to
`process-sbom.sh`, which collects Yocto `create-spdx` outputs.

```bash
bash scripts/generate-sbom.sh
# Output: collected SPDX files in sbom/
```

### `process-sbom.sh`

Post-processes SBOM for CI validation.

### `verify-image.sh`

Sanity checks on the final rootfs image (Python runtime coverage, etc.).

### `audit-image-deps.sh`

Dependency-closure audit for an image target (dry-run, no compile).
- Generates `pn-buildlist` and `task-depends.dot`
- Flags common bloat candidates

```bash
su - builder -c 'cd /workspace && bash scripts/audit-image-deps.sh core-image-medtech'
```

---

## Recommended Workflows

### User: Run the latest release

```bash
bash scripts/setup-host-qemu-prereqs.sh   # once
bash scripts/download-and-run-qemu.sh     # every time
```

### Developer: Build and test locally

```bash
# In the dev container terminal:
bash scripts/quick-setup.sh
bitbake core-image-medtech
bash scripts/run-qemu.sh     # boot and test
```

### Developer: Iterate on a single recipe

```bash
bitbake -c cleansstate medtech-vitals-publisher
bitbake medtech-vitals-publisher
bash scripts/run-qemu.sh
```

### Maintainer: Before pushing to CI

```bash
bash scripts/quick-setup.sh
bitbake core-image-medtech                            # canonical full build
bash scripts/build-robust.sh                          # optional deep diagnostics
bash scripts/generate-sbom.sh                         # collect SPDX outputs
bash scripts/verify-image.sh python-sanity            # check Python packages
bash scripts/package-release-artifacts.sh --image-name core-image-medtech
bash scripts/verify-release-package.sh --image-name core-image-medtech
```
