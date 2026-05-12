# MedTech Device OS

Embedded Linux distribution for a medical IoT reference device, built with Yocto
Project (kirkstone) for ARM64.

This README is a quick orientation page. Detailed implementation and operations
guidance live under `docs/`.

---

## What This Repository Provides

- Yocto layer and image definition for `core-image-medtech`
- Local development workflow via VS Code dev container + QEMU
- CI/CD packaging for downloadable QEMU release bundles
- Security and compliance workflow with SPDX and Vigiles integration

## Where To Find What

- Architecture overview: [docs/reference/architecture-reference.md](docs/reference/architecture-reference.md)
- Yocto layer structure: [docs/reference/layer-structure.md](docs/reference/layer-structure.md)
- Build and dev workflow: [docs/guides/build-guide.md](docs/guides/build-guide.md)
- CI/CD pipeline behavior: [docs/maintainers/ci-cd.md](docs/maintainers/ci-cd.md)
- Release and promotion process: [docs/maintainers/release-process.md](docs/maintainers/release-process.md)
- SBOM and compliance strategy: [docs/guides/sbom-strategy.md](docs/guides/sbom-strategy.md)
- SSH setup and hardening: [docs/guides/ssh-provisioning.md](docs/guides/ssh-provisioning.md)
- Deployment troubleshooting: [docs/guides/deployment-troubleshooting.md](docs/guides/deployment-troubleshooting.md)
- Test procedures: [TESTING.md](TESTING.md)

## Architecture Snapshot

Core runtime components included in the image:

- Mosquitto MQTT broker
- Vitals publisher service
- Edge analytics service (TFLite-based)
- Clinician UI service (Qt6, headless/offscreen in QEMU)
- systemd service orchestration

High-level service/data flow:

```text
medtech-vitals-publisher -> mosquitto -> medtech-edge-analytics -> medtech-clinician-ui
         medtech/vitals/latest                 medtech/predictions/sepsis
```

Systemd startup order (dependency chain):

```text
mosquitto.service
  -> medtech-vitals-publisher.service
    -> medtech-edge-analytics.service
      -> medtech-clinician-ui.service
```

Deep dive: [docs/reference/architecture-reference.md](docs/reference/architecture-reference.md)

## Layer Snapshot

Top-level custom layer layout:

```text
yocto/meta-medtech/
      conf/
      classes/
      recipes-core/
      recipes-image/
      recipes-services/
      recipes-support/
```

Deep dive: [docs/reference/layer-structure.md](docs/reference/layer-structure.md)

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
ssh -p 2222 medadmin@localhost
```

SSH password auth is disabled by default. Provision your public key via
`MEDTECH_ADMIN_AUTHORIZED_KEY` in `yocto/build/conf/local.conf` before building.

- Full guide: [docs/getting-started/quick-start-user.md](docs/getting-started/quick-start-user.md)
- Commands: [docs/reference/quick-reference.md](docs/reference/quick-reference.md)
- SSH key setup: [docs/guides/ssh-provisioning.md](docs/guides/ssh-provisioning.md)
- Documentation home: [docs/readme.md](docs/readme.md)

---

## For Developers: Build from Source

### Prerequisites

- VS Code with [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- Docker Desktop

### 1. Open in dev container

```
Ctrl+Shift+P → Dev Containers: Reopen in Container
```

Setup runs automatically.

### 2. Build

```bash
bitbake core-image-medtech
```

### 3. Boot and test

```bash
bash scripts/run-qemu.sh
```

- Full guide: [docs/getting-started/quick-start-developer.md](docs/getting-started/quick-start-developer.md)
- Build details: [docs/guides/build-guide.md](docs/guides/build-guide.md)
- Layer structure: [docs/reference/layer-structure.md](docs/reference/layer-structure.md)
- Scripts: [scripts/README.md](scripts/README.md)

---

## For Maintainers: CI/CD and Releases

This project ships a release bundle for end users and a separate private
security artifact flow for Vigiles data.

- CI details: [docs/maintainers/ci-cd.md](docs/maintainers/ci-cd.md)
- Release process: [docs/maintainers/release-process.md](docs/maintainers/release-process.md)
- SBOM and compliance: [docs/guides/sbom-strategy.md](docs/guides/sbom-strategy.md)

---

## Current Status and Gaps

### Current

- Core build and QEMU boot flow are active for `core-image-medtech`
- SPDX generation is supported through Yocto `create-spdx` when enabled
- Vigiles integration is available for vulnerability/compliance workflows

### Planned

- Provide a clearer, release-grade compliance packaging profile for security
      artifacts (SPDX + Vigiles outputs)

### Investigating

- Whether to publish an additional CycloneDX export derived from SPDX outputs
      for downstream tools that require CycloneDX specifically
- Whether to enforce SPDX generation for selected release lanes by default

---

## Quick Runtime Checks

After booting QEMU and connecting over SSH:

```bash
# Verify key services
systemctl status mosquitto medtech-vitals-publisher medtech-edge-analytics medtech-clinician-ui

# Observe MQTT traffic
mosquitto_sub -t "medtech/#" -v

# Confirm image build metadata
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

## Documentation

Start with [docs/readme.md](docs/readme.md) for role-based navigation and
[docs/index.md](docs/index.md) for the complete file index.

- Users: [docs/getting-started/quick-start-user.md](docs/getting-started/quick-start-user.md)
- Developers: [docs/getting-started/quick-start-developer.md](docs/getting-started/quick-start-developer.md)
- Maintainers: [docs/maintainers/ci-cd.md](docs/maintainers/ci-cd.md)
- Testing checklist: [TESTING.md](TESTING.md)
