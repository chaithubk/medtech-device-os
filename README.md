# MedTech Device OS

Embedded Linux operating system for medical IoT devices. Built with Yocto Project
(kirkstone) for ARM64. Runs and develops entirely in QEMU — no physical hardware required.

---

## What is MedTech Device OS?

A production-grade embedded Linux OS that demonstrates a complete medical IoT stack:

- **MQTT Broker** (Mosquitto) — device communication fabric
- **Vitals Publisher** — simulates patient vitals every 10 seconds
- **Edge Analytics** — TensorFlow Lite sepsis risk detection (on-device ML)
- **Clinician UI** — Qt6 dashboard (headless/offscreen in QEMU)
- **Systemd** — full service management with proper dependency chains
- **CycloneDX SBOM** — automated software bill of materials
- **GitHub Releases** — ready-to-run QEMU images, no Docker required

---

## For Users: Run the Latest Release

No build required. No Docker required.

### 1. Install QEMU (one-time)

```bash
bash scripts/setup-host-qemu-prereqs.sh
```

### 2. Download and run

```bash
bash scripts/download-and-run-qemu.sh
```

The script downloads the latest release, verifies checksums, boots QEMU, and
**automatically waits for SSH** to become ready.

### 3. Connect

```bash
ssh -p 2222 root@localhost
# Password: root
```

📖 **Full guide:** [docs/QUICK_START_USER.md](docs/QUICK_START_USER.md)
📋 **Commands:** [docs/QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md)
🔧 **Troubleshooting:** [docs/DEPLOYMENT_TROUBLESHOOTING.md](docs/DEPLOYMENT_TROUBLESHOOTING.md)

---

## For Developers: Build from Source

### Prerequisites

- VS Code with [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- Docker Desktop

### 1. Open in dev container

```
Ctrl+Shift+P → Dev Containers: Reopen in Container
```

Setup runs automatically (`quick-setup.sh` clones Yocto layers and initializes the build config).

### 2. Build

```bash
bitbake core-image-medtech
```

The `bitbake` command is a wrapper that handles the root→builder privilege drop and
Yocto environment setup automatically. See [`scripts/bitbake`](scripts/bitbake).

### 3. Boot and test

```bash
bash scripts/run-qemu.sh
```

📖 **Full guide:** [docs/QUICK_START_DEVELOPER.md](docs/QUICK_START_DEVELOPER.md)
🏗 **Build options:** [docs/BUILD_GUIDE.md](docs/BUILD_GUIDE.md)
📦 **Layer structure:** [docs/LAYER_STRUCTURE.md](docs/LAYER_STRUCTURE.md)

---

## For Maintainers: CI/CD and Releases

### GitHub Actions pipeline

The pipeline (`.github/workflows/device-build-smart.yml`) automatically:
1. Builds `core-image-medtech` on every push/PR to `main`
2. Runs post-build policy checks (no debug packages, Python sanity)
3. Packages the QEMU bundle (`package-release-artifacts.sh`)
4. Creates a GitHub Release on `main` branch merges

```bash
# Package release bundle (used by CI)
bash scripts/package-release-artifacts.sh --image-name core-image-medtech

# Verify the bundle
bash scripts/verify-release-package.sh --image-name core-image-medtech
```

📖 **CI details:** [docs/CI_CD.md](docs/CI_CD.md)
🚀 **Release process:** [docs/RELEASE_PROCESS.md](docs/RELEASE_PROCESS.md)

---

## Architecture

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

📖 **Full architecture:** [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

---

## Layer Structure

```
yocto/meta-medtech/
├── conf/layer.conf                      # Layer registration
├── classes/medtech-image.bbclass        # Image policy
├── recipes-core/medtech-system/         # Base OS config
├── recipes-services/                    # Application services
│   ├── medtech-vitals-publisher/
│   ├── medtech-edge-analytics/
│   └── medtech-clinician-ui/
├── recipes-support/                     # Third-party packages
│   ├── mosquitto/
│   ├── python3-paho-mqtt/
│   └── tensorflow-lite/
└── recipes-image/core-image-medtech/    # Image definition
```

📖 **Layer guide:** [yocto/meta-medtech/README.md](yocto/meta-medtech/README.md)

---

## Sanity Checks (inside QEMU)

```bash
# Verify all services are running
systemctl status mosquitto medtech-vitals-publisher medtech-edge-analytics medtech-clinician-ui

# Watch MQTT data flow
mosquitto_sub -t "medtech/#" -v

# Check image version
cat /etc/medtech-release
```

---

## CI/CD Quick Reference

| What | File |
|---|---|
| GitHub Actions workflow | `.github/workflows/device-build-smart.yml` |
| CI layer config (canonical) | `yocto/conf/bblayers.conf.sample` |
| CI build config (canonical) | `yocto/conf/local.conf.sample` |
| Release bundle packaging | `scripts/package-release-artifacts.sh` |
| Bundle verification | `scripts/verify-release-package.sh` |

---

## Documentation Index

| Audience | Document |
|---|---|
| Users | [docs/QUICK_START_USER.md](docs/QUICK_START_USER.md) |
| Users | [docs/QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md) |
| Users | [docs/DEPLOYMENT_TROUBLESHOOTING.md](docs/DEPLOYMENT_TROUBLESHOOTING.md) |
| Developers | [docs/QUICK_START_DEVELOPER.md](docs/QUICK_START_DEVELOPER.md) |
| Developers | [docs/BUILD_GUIDE.md](docs/BUILD_GUIDE.md) |
| Developers | [docs/LAYER_STRUCTURE.md](docs/LAYER_STRUCTURE.md) |
| Developers | [docs/RECIPES.md](docs/RECIPES.md) |
| Developers | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| Maintainers | [docs/CI_CD.md](docs/CI_CD.md) |
| Maintainers | [docs/RELEASE_PROCESS.md](docs/RELEASE_PROCESS.md) |
| All | [docs/README.md](docs/README.md) — documentation landing page |
| All | [TESTING.md](TESTING.md) — test procedures |
