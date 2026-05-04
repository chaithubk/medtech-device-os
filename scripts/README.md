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

## 👨‍💻 Developer Scripts (build inside dev container)

### `bitbake` *(wrapper — not a script you call directly)*

**A transparent wrapper around the real BitBake binary. This is what makes `bitbake` work everywhere in the container.**

- Detects if the build environment is initialized; runs `quick-setup.sh` if not
- **Automatically drops from root to the `builder` user** (BitBake refuses root builds)
- Sources `oe-init-build-env` before calling the real BitBake
- Preserves all arguments and flags passed to it

```bash
# Works from any directory in the container:
bitbake core-image-medtech
bitbake medtech-vitals-publisher
bitbake -c cleansstate medtech-system && bitbake medtech-system
bitbake -p   # parse only
```

This wrapper lives at `scripts/bitbake` and is found first because
`/workspace/scripts` is prepended to `PATH` in `.devcontainer/devcontainer.json`.

See the file itself for the full documented implementation.

---

### `build.sh`

**Quick local build** for development iteration.

- Initializes Yocto environment in one step
- Adds local workarounds for Qt/network issues
- Suitable for: testing recipe changes, quick iterations

```bash
bash scripts/build.sh
```

---

### `build-robust.sh`

**Production-grade build** with full diagnostics and error recovery.

- Runs pre-flight checks → clones layers with retry → builds with diagnostics
- Collects disk usage, compiler versions, failed task logs
- Matches CI pipeline behavior
- Suitable for: final validation before CI push, reproducible builds

```bash
bash scripts/build-robust.sh
```

---

### `run-qemu.sh`

**Boot the locally-built image in QEMU** (after `bitbake core-image-medtech`).

- Validates kernel and rootfs exist in the deploy directory
- Launches `qemu-system-aarch64` with proper device configuration
- SSH available on `localhost:2222`

```bash
bash scripts/run-qemu.sh           # nographic (terminal console)
bash scripts/run-qemu.sh --graphics  # with GTK display
```

**Inside QEMU:**
```bash
# Login: root / Password: root
systemctl status mosquitto
mosquitto_sub -t "medtech/#" -v
```

**SSH from host:**
```bash
ssh -p 2222 root@localhost   # Password: root
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

**One-time setup** (runs automatically via `postCreateCommand`). Clones Yocto
layers and initializes `yocto/build/conf/`. The `bitbake` wrapper calls this
automatically if needed.

### `setup-devenv.sh`

Extended environment setup (installs host tools, clones layers). Use
`quick-setup.sh` for most cases.

### `clone-with-retry.sh`

Clones Yocto layers with retry logic and mirror fallback. Called by `build-robust.sh`.

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

Generates CycloneDX SBOM from the built image.
```bash
bash scripts/generate-sbom.sh
# Output: sbom/sbom.json
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
bitbake core-image-medtech   # full build
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
bash scripts/build-robust.sh                          # full validation build
bash scripts/generate-sbom.sh                         # generate SBOM
bash scripts/verify-image.sh python-sanity            # check Python packages
bash scripts/package-release-artifacts.sh --image-name core-image-medtech
bash scripts/verify-release-package.sh --image-name core-image-medtech
```
