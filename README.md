# MedTech Device OS

Embedded Linux operating system for medical IoT devices using Yocto Project (kirkstone).

## Table of Contents

- [Start Here](#start-here)
- [Deployment](#deployment)
- [Stage 1: QEMU Emulation](#stage-1-qemu-emulation)
- [Features](#features)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Sanity Checks Inside QEMU](#sanity-checks-inside-qemu)
- [Generate SBOM](#generate-sbom)
- [SSH Access After Boot (both paths)](#ssh-access-after-boot-both-paths)
- [CI/CD](#cicd)
- [Which Files Affect CI vs Local Builds?](#which-files-affect-ci-vs-local-builds)
- [Local Reproducible Build Notes](#local-reproducible-build-notes)
- [Disk Space Optimization](#disk-space-optimization)
- [Layer Structure](#layer-structure)
- [Documentation Index](#documentation-index)

## Start Here

If you are new to this repository, follow this order:

1. Run the build steps in [Quick Start](#quick-start).
2. Boot and validate behavior with [Sanity Checks Inside QEMU](#sanity-checks-inside-qemu).
3. Review CI behavior in [CI/CD](#cicd).
4. Use the troubleshooting docs in [Documentation Index](#documentation-index).

## Deployment


This project supports two deployment/testing paths for QEMU images.

### Packaging and Verifying GHCR Artifacts

After building your image, you can package the QEMU artifacts for distribution and verify their integrity using the provided scripts:

#### 1. Package the Artifacts

```bash
bash scripts/package-ghcr-artifacts.sh --image-name core-image-medtech
```

Expected output:

```
=== GHCR bundle created ===
Output directory : /workspace/artifacts
Archive : /workspace/artifacts/core-image-medtech-qemuarm64-bundle.tar.gz
Manifest : /workspace/artifacts/core-image-medtech-qemuarm64-manifest.json
Checksums : /workspace/artifacts/SHA256SUMS
```

Artifacts produced:

- core-image-medtech-qemuarm64-bundle.tar.gz
- core-image-medtech-qemuarm64-manifest.json
- SHA256SUMS

#### 2. Verify the Artifacts

```bash
bash scripts/verify-ghcr-package.sh --image-name core-image-medtech
```

Expected output:

```
core-image-medtech-qemuarm64-bundle.tar.gz: OK
core-image-medtech-qemuarm64-manifest.json: OK
=== GHCR bundle verification passed ===
Archive: /workspace/artifacts/core-image-medtech-qemuarm64-bundle.tar.gz
Contents summary:
payload/image/
payload/image/core-image-medtech-qemuarm64-<timestamp>.rootfs.ext4
payload/image/Image-qemuarm64.bin
payload/metadata/
payload/metadata/core-image-medtech-qemuarm64-<timestamp>.rootfs.manifest
payload/metadata/core-image-medtech-qemuarm64.testdata.json
payload/metadata/core-image-medtech-qemuarm64.qemuboot.conf
payload/metadata/manifest.json
```

This ensures the archive and manifest are valid and the payload contains the expected files.

---

### Path A: Run a Locally Built Image (inside dev container)

1. Build image: `bitbake core-image-medtech`
2. Boot image: `bash scripts/run-qemu.sh`
3. Verify services: use [Sanity Checks Inside QEMU](#sanity-checks-inside-qemu)

Boot command details (terminal mode):

```bash
bash scripts/run-qemu.sh
```

### Path B: Run a GHCR Image on Ubuntu Host (outside container)

1. Prepare host once:

```bash
bash scripts/setup-host-qemu-prereqs.sh
```

2. Run GHCR image (kernel + rootfs auto-detected from `/artifacts/`):

```bash
bash scripts/run-ghcr-qemu.sh --image ghcr.io/<owner>/<repo>/qemu-image:latest
```

3. Connect with SSH using [SSH Access After Boot (both paths)](#ssh-access-after-boot-both-paths).

### GHCR Unauthorized Error (quick fix)

If pull fails with `unauthorized`, authenticate Docker to GHCR:

```bash
export GHCR_PAT=<token-with-read:packages>
echo "$GHCR_PAT" | docker login ghcr.io -u <github-username> --password-stdin
```

If the package belongs to an organization, ensure the token is SSO-authorized for that org.

### Missing Kernel in Older GHCR Images

If you have an older GHCR image that only contains `.ext4` (no kernel), provide kernel path explicitly:

```bash
bash scripts/run-ghcr-qemu.sh \
  --image ghcr.io/<owner>/<repo>/qemu-image:old-tag \
  --kernel /path/to/Image-qemuarm64.bin
```

New builds (after this CI fix) include kernel + rootfs + dtb in `/artifacts/`, so you won't need `--kernel`.

### SSH Access After Boot (both paths)

```bash
ssh -p 2222 root@localhost
```

## Stage 1: QEMU Emulation

### Features

- ✅ Yocto/Poky kirkstone build system
- ✅ `core-image-medtech` custom image
- ✅ **MQTT Broker** (Mosquitto) – auto-starts on boot
- ✅ **Vitals Publisher** – publishes simulated patient vitals every 10 s
- ✅ **Edge Analytics** – TensorFlow Lite sepsis detection
- ✅ **Clinician UI** – Qt6 dashboard (headless/offscreen for QEMU)
- ✅ Systemd service management with proper dependency chain
- ✅ CycloneDX SBOM generation
- ✅ QEMU ARM64 emulator
- ✅ SSH server
- ✅ CI/CD via GitHub Actions → GHCR

### Architecture

```
MQTT Data Flow
──────────────
Vitals Publisher ──→ mosquitto (1883) ──→ Edge Analytics ──→ Clinician UI
   (Python)              (MQTT)              (TFLite)          (Qt6)

Topic: medtech/vitals/latest          medtech/predictions/sepsis

Systemd Dependency Chain
────────────────────────
mosquitto.service
  └── medtech-vitals-publisher.service
        └── medtech-edge-analytics.service
              └── medtech-clinician-ui.service
```

### Quick Start

#### Build in Dev Container

```bash
# Reopen folder in container
# Cmd+Shift+P → Dev Containers: Reopen in Container

# The dev container post-create step runs quick-setup automatically.
# After the container is ready, build directly:
bitbake core-image-medtech
```

#### Build a Single Recipe Locally

```bash
# Example: build only the clinician UI recipe
bitbake medtech-clinician-ui

# Optional: force clean rebuild of that recipe
bitbake -c cleansstate medtech-clinician-ui
bitbake medtech-clinician-ui
```

#### Build Full Image (Manual Path)

```bash
bash scripts/setup-devenv.sh
bash scripts/clone-with-retry.sh
su - builder -c 'cd /workspace && source yocto/poky/oe-init-build-env yocto/build >/dev/null && cp -n ../conf/local.conf.sample conf/local.conf && cp -n ../conf/bblayers.conf.sample conf/bblayers.conf && bitbake core-image-medtech'
```

#### Boot in QEMU

Use the canonical deployment instructions in [Deployment](#deployment).

---

### Sanity Checks Inside QEMU

After booting, log in as `root` and run the following checks:

#### 1. Check all services are running

```bash
systemctl status mosquitto
systemctl status medtech-vitals-publisher
systemctl status medtech-edge-analytics
systemctl status medtech-clinician-ui
```

Expected: all four services show `active (running)`.

#### 2. Verify MQTT data flow

Open two terminals (or use `tmux`/`screen`):

```bash
# Terminal 1 – subscribe to all medtech topics
mosquitto_sub -t "medtech/#" -v

# Terminal 2 – wait ~10 seconds; you should see output like:
# medtech/vitals/latest {"heart_rate": 75, "spo2": 98, ...}
# medtech/predictions/sepsis {"risk": 0.12, "alert": false}
```

#### 3. Inspect service logs

```bash
journalctl -u medtech-vitals-publisher -n 50
journalctl -u medtech-edge-analytics   -n 50
journalctl -u medtech-clinician-ui     -n 50
```

#### 4. Verify image metadata

```bash
cat /etc/medtech-release
```

#### 5. Exit QEMU

```bash
# Press Ctrl+A then X
# or
shutdown -h now
```

---

### Generate SBOM

```bash
bash scripts/generate-sbom.sh
# Output: sbom/sbom.json  (CycloneDX 1.4 format)
```

### CI/CD

GitHub Actions (`.github/workflows/device-build-smart.yml`) automatically:
1. Validates the layer structure
2. Builds `core-image-minimal` for pull requests and `core-image-medtech` for pushes to `main`
3. Runs the medtech-specific manifest and Python runtime checks on `main` builds
4. Uploads the built `.ext4` image as an artifact
5. Uploads the SPDX SBOM for `core-image-medtech` builds
6. **Packages kernel, rootfs, and DTB into a Docker image and pushes to GHCR** (`ghcr.io/<owner>/medtech-device-os/qemu-image:latest` for main branch)

#### GHCR Image Contents

The Docker image pushed to GHCR contains:
- Yocto kernel image (`Image` or `Image-qemuarm64.bin`)
- Rootfs image (`*.ext4`)
- Device tree blob (`*.dtb`, if available)
- SPDX SBOM files (for `core-image-medtech` only)

All artifacts are located in `/artifacts/` inside the container for easy extraction.

#### Build Artifacts, Archives, and Retention

Successful workflow runs archive the built image in GitHub Actions artifacts.

1. Pull request runs archive `core-image-minimal-qemuarm64.ext4`.
2. Pushes to `main` archive `core-image-medtech-qemuarm64.ext4`.
3. Artifact name in GitHub Actions for PR runs: `qemu-image-minimal`.
4. Artifact name in GitHub Actions for `main` branch runs: `qemu-image-medtech`.
5. Artifact retention: 30 days.

To find a successfully built image in GitHub:

1. Open the repository on GitHub.
2. Go to the **Actions** tab.
3. Open the workflow run for the pull request or the `main` branch push you care about.
4. In the run summary, open the **Artifacts** section.
5. Download `qemu-image-minimal` for PR runs or `qemu-image-medtech` for `main` branch runs.
6. Extract it locally to get the built `.ext4` image.

Notes:

1. PR runs are intended as a lightweight sanity check, so the archived image is the minimal image.
2. After a PR is merged, the push to `main` runs the full `core-image-medtech` build and archives that image separately.
3. If a build fails before the packaging step, the final image artifact may not exist, but failure debug artifacts can still be uploaded by the workflow.

CI notes:
1. CI does not call `quick-setup.sh` or `setup-devenv.sh`; it runs explicit workflow steps.
2. CI generates `yocto/build/conf/bblayers.conf` by copying `yocto/conf/bblayers.conf.sample` during each run.
3. Local edits to `yocto/build/conf/bblayers.conf` do not affect CI unless the sample file and workflow are updated and committed.
4. Local bootstrap scripts may append dev-container-only workarounds to `yocto/build/conf/local.conf`; those do not change CI behavior.

#### Which Files Affect CI vs Local Builds?

Files that affect CI behavior:
1. `.github/workflows/device-build-smart.yml` — CI job definition and build steps.
2. `yocto/conf/bblayers.conf.sample` — source for CI `bblayers.conf`.
3. `yocto/conf/local.conf.sample` — source for CI `local.conf`.
4. `yocto/meta-medtech/**` — recipes and layer metadata used by both CI and local builds.

Files that are local/dev-container only:
1. `.devcontainer/Dockerfile` and `.devcontainer/devcontainer.json` — local container setup.
2. `scripts/setup-devenv.sh`, `scripts/quick-setup.sh`, and `scripts/clone-with-retry.sh` — local bootstrap helpers.
3. `yocto/build/conf/bblayers.conf` and `yocto/build/conf/local.conf` — generated local build config files.

#### Local Reproducible Build Notes

The dev container includes a few local-only adjustments so builds are reproducible after reopening or rebuilding the container:

1. Installs missing Yocto host tools in the dev container.
2. Uses a non-root `builder` user because BitBake refuses root builds.
3. Ensures `/workspace` is writable by `builder`.
4. Uses retry and mirror fallback for layer fetches in environments with proxy or TLS/certificate issues.
5. Adds a local-only `CONNECTIVITY_CHECK_URIS` override to the generated local `local.conf` when needed.

These local workarounds are intended to make dev-container builds reproducible without changing the CI pipeline behavior.

### Disk Space Optimization

The build is optimized for GitHub Actions runners (limited to ~14 GB disk space):

- **Minimal image packages**: Removed `python3-pip`, `wget`, `nano`, `htop`, `rsyslog`, `mesa` (~500 MB-1 GB saved)
- **No SDK builds**: `SDKMACHINE = ""` prevents cross-compilation SDK generation (~2-3 GB saved)
- **Strip debug symbols**: `INHIBIT_PACKAGE_DEBUG_SPLIT = "1"` (~1-2 GB saved)
- **No API documentation**: `DISTRO_FEATURES:remove = "api-documentation"` (~200-500 MB saved)
- **No SPDX sources**: `SPDX_INCLUDE_SOURCES = "0"` (~500 MB-1 GB saved)
- **CI pre-build cleanup**: Removes dotnet, android, ghc, CodeQL (~12-15 GB freed)

See [docs/DISK_OPTIMIZATION.md](docs/DISK_OPTIMIZATION.md) for detailed strategy.

### Layer Structure

```
yocto/meta-medtech/
├── conf/layer.conf
├── classes/medtech-image.bbclass
├── recipes-core/medtech-system/medtech-system.bb
├── recipes-services/
│   ├── medtech-vitals-publisher/medtech-vitals-publisher_1.0.bb
│   ├── medtech-edge-analytics/medtech-edge-analytics_1.0.bb
│   └── medtech-clinician-ui/medtech-clinician-ui_1.0.bb
├── recipes-support/
│   ├── mosquitto/mosquitto_%.bbappend
│   ├── python3-paho-mqtt/python3-paho-mqtt_1.6.1.bb
│   └── tensorflow-lite/tensorflow-lite_2.14.0.bb
└── recipes-image/core-image-medtech/core-image-medtech.bb
```

## Documentation Index

- [docs/README.md](docs/README.md) - Documentation landing page.
- [docs/yocto-ci-failure-detection.md](docs/yocto-ci-failure-detection.md) - CI-first failure triage runbook.
- [docs/yocto-fetch-and-mirror-notes.md](docs/yocto-fetch-and-mirror-notes.md) - Fetch failure and mirror guidance.
- [docs/yocto-generated-config-notes.md](docs/yocto-generated-config-notes.md) - Generated config behavior and drift notes.
- [docs/yocto-local-recovery-notes.md](docs/yocto-local-recovery-notes.md) - Local recovery steps.
- [docs/yocto-single-recipe-build-notes.md](docs/yocto-single-recipe-build-notes.md) - Fast local iteration with single-recipe builds.
- [docs/yocto-build-pause-resume-notes.md](docs/yocto-build-pause-resume-notes.md) - Pausing and resuming long builds.
- [docs/DISK_OPTIMIZATION.md](docs/DISK_OPTIMIZATION.md) - Disk pressure mitigation strategy.
- [docs/SBOM_STRATEGY.md](docs/SBOM_STRATEGY.md) - SBOM generation and compliance strategy.
