# MedTech Device OS

Embedded Linux operating system for medical IoT devices using Yocto Project (kirkstone).

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

# Initialize Yocto and local build config
bash scripts/quick-setup.sh

# Build MedTech image as non-root (Yocto blocks root builds)
su - builder -c 'cd /workspace && source yocto/poky/oe-init-build-env yocto/build >/dev/null && bitbake core-image-medtech'
```

#### Build a Single Recipe Locally

```bash
# Example: build only the clinician UI recipe
su - builder -c 'cd /workspace && source yocto/poky/oe-init-build-env yocto/build >/dev/null && bitbake medtech-clinician-ui'

# Optional: force clean rebuild of that recipe
su - builder -c 'cd /workspace && source yocto/poky/oe-init-build-env yocto/build >/dev/null && bitbake -c cleansstate medtech-clinician-ui && bitbake medtech-clinician-ui'
```

#### Build Full Image (Manual Path)

```bash
bash scripts/setup-devenv.sh
bash scripts/clone-with-retry.sh
su - builder -c 'cd /workspace && source yocto/poky/oe-init-build-env yocto/build >/dev/null && cp -n ../conf/local.conf.sample conf/local.conf && cp -n ../conf/bblayers.conf.sample conf/bblayers.conf && bitbake core-image-medtech'
```

#### Boot in QEMU

```bash
# From the yocto/build directory
runqemu qemuarm64 core-image-medtech nographic

# Login: root  (no password)
```

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

### SSH into QEMU

```bash
ssh -p 2222 root@localhost
```

### CI/CD

GitHub Actions (`.github/workflows/device-build-smart.yml`) automatically:
1. Validates the layer structure
2. Builds `core-image-medtech` with BitBake
3. Generates and validates the CycloneDX SBOM
4. Uploads the `.ext4` image and SBOM as artifacts
5. Pushes a tagged Docker image to GHCR (`ghcr.io/<owner>/medtech-device-os/qemu-image`)

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

See [`DISK_OPTIMIZATION.md`](DISK_OPTIMIZATION.md) for detailed strategy.

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
