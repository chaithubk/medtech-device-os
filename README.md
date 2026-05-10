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
ssh -p 2222 medadmin@localhost
```

SSH password auth is disabled by default. Provision your public key via
`MEDTECH_ADMIN_AUTHORIZED_KEY` in `yocto/build/conf/local.conf` before building.

- 📖 **Full guide:** [docs/getting-started/quick-start-user.md](docs/getting-started/quick-start-user.md)
- 📋 **Commands:** [docs/reference/quick-reference.md](docs/reference/quick-reference.md)
- 🔐 **SSH key setup:** [docs/guides/ssh-provisioning.md](docs/guides/ssh-provisioning.md)
- 🧭 **All docs:** [docs/](docs/)

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

- 📖 **Full guide:** [docs/getting-started/quick-start-developer.md](docs/getting-started/quick-start-developer.md)
- 🏗 **Build details:** [docs/guides/build-guide.md](docs/guides/build-guide.md)
- 📦 **Layer structure:** [docs/reference/layer-structure.md](docs/reference/layer-structure.md)
- 🧭 **All scripts:** [scripts/README.md](scripts/README.md)

---

## For Maintainers: CI/CD and Releases

### GitHub Actions pipeline

The pipeline (`.github/workflows/device-build-smart.yml`) automatically:
1. Builds `core-image-medtech` on every push/PR to `main`
2. Runs post-build policy checks (no debug packages, Python sanity)
3. Packages the QEMU bundle (`package-release-artifacts.sh`)
4. Creates a GitHub Release on `main` branch merges

5. **Packages a private Vigiles bundle** (see below)

```bash
# Package release bundle (used by CI)
bash scripts/package-release-artifacts.sh --image-name core-image-medtech

# Verify the bundle
bash scripts/verify-release-package.sh --image-name core-image-medtech
```

- 📖 **CI details:** [docs/maintainers/ci-cd.md](docs/maintainers/ci-cd.md)
- 🚀 **Release process:** [docs/maintainers/release-process.md](docs/maintainers/release-process.md)

#### Private Vigiles Bundle

The CI workflow creates a **separate, private artifact bundle** containing Vigiles vulnerability/configuration files:

- `core-image-medtech-cve.json`
- `linux-yocto-*.config`

This bundle is uploaded as a separate artifact (`qemu-image-medtech-vigiles-private`), and is **not included in the public release**.

**Encryption:**
- If the repository secret `VIGILES_PRIVATE_BUNDLE_PASSPHRASE` is set, the private bundle is encrypted with AES-256 using OpenSSL.
- Only someone with the passphrase can decrypt and access the contents.

**How to set the passphrase:**
1. Go to your repository's Settings → Secrets and variables → Actions.
2. Add a new secret named `VIGILES_PRIVATE_BUNDLE_PASSPHRASE` with a strong, private value (e.g., a long random string).

**How to decrypt:**
Download the `.tar.gz.enc` file from the workflow artifacts and run:

```bash
openssl enc -d -aes-256-cbc -pbkdf2 -in core-image-medtech-qemuarm64-vigiles-private.tar.gz.enc -out core-image-medtech-qemuarm64-vigiles-private.tar.gz
# Then extract:
tar -xzf core-image-medtech-qemuarm64-vigiles-private.tar.gz
```

**Keep your passphrase secure!** Only those with the secret can access the private Vigiles bundle.

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

- 📖 **Full architecture:** [docs/reference/architecture-reference.md](docs/reference/architecture-reference.md)

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

- 📖 **Layer guide:** [yocto/meta-medtech/README.md](yocto/meta-medtech/README.md)

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

## Documentation

For complete guides, see **[docs/](docs/)** or the quick links above.

| Audience | Document |
|---|---|
| Users | [Quick start](docs/getting-started/quick-start-user.md) \| [Reference](docs/reference/quick-reference.md) |
| Developers | [Quick start](docs/getting-started/quick-start-developer.md) \| [Build guide](docs/guides/build-guide.md) \| [Recipes](docs/guides/recipes.md) |
| Maintainers | [CI/CD](docs/maintainers/ci-cd.md) \| [Release](docs/maintainers/release-process.md) |
| Reference | [Architecture](docs/reference/architecture-reference.md) \| [Layers](docs/reference/layer-structure.md) |
| Testing | [Checklist](TESTING.md) |
