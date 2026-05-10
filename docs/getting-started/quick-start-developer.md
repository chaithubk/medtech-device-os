# Quick Start: Developer Build Guide

> **Goal:** Open the dev container, build the full MedTech Device OS image, and boot it in QEMU in under 10 minutes (after initial setup).

---

## Prerequisites

- [VS Code](https://code.visualstudio.com/) with the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or Docker Engine on Linux)
- ~30 GB free disk space for the Yocto build cache

---

## Step 1: Open in Dev Container

1. Clone the repository:
   ```bash
   git clone https://github.com/chaithubk/medtech-device-os.git
   cd medtech-device-os
   ```

2. Open in VS Code:
   ```bash
   code .
   ```

3. When prompted "Reopen in Container", click **Reopen in Container**.
   - Or: `Ctrl+Shift+P` → **Dev Containers: Reopen in Container**

4. The container builds and then runs `quick-setup.sh` automatically.
   - This clones the Yocto layers (poky, meta-openembedded, meta-qt6, meta-timesys) — takes ~2 minutes on first run.
   - Subsequent opens are instant (layers are already present).

5. Wait for the "postCreateCommand" to complete in the VS Code terminal.

---

## Step 2: Build the image

Open a terminal in VS Code (`` Ctrl+` ``) and run:

```bash
bitbake core-image-medtech
```

That's it. The `bitbake` wrapper automatically:
- Drops privileges from root to the `builder` user (BitBake requires non-root)
- Sources the Yocto build environment
- Runs the full image build

> **First build takes 60–120 minutes** as it compiles everything from source.
> Subsequent builds with unchanged recipes take a few minutes (sstate cache).

### Build single recipes (faster iteration)

```bash
# Build only one recipe
bitbake medtech-vitals-publisher

# Force clean rebuild of a recipe
bitbake -c cleansstate medtech-vitals-publisher
bitbake medtech-vitals-publisher

# Check what a recipe expands to (no build)
bitbake -e medtech-vitals-publisher | grep ^SRC_URI
```

---

## Step 3: Boot in QEMU

```bash
bash scripts/run-qemu.sh
```

This launches QEMU with the just-built image. The terminal becomes the QEMU serial console.

**Default login policy:**
- Root password login is disabled
- SSH password authentication is disabled
- Managed admin account: `medadmin` (SSH key required)

**SSH from another terminal on your host:**
```bash
ssh -i ~/.ssh/id_medtech -p 2222 medadmin@localhost
```

> **SSH key provisioning required:** Before SSH will work, you must add your public key
> to `.secrets/medtech-admin-key.pub` and rebuild. See the full guide at
> [../guides/ssh-provisioning.md](../guides/ssh-provisioning.md) or quick start:
> ```bash
> cat ~/.ssh/id_medtech.pub > .secrets/medtech-admin-key.pub
> bitbake -c cleansstate core-image-medtech && bitbake core-image-medtech
> bash scripts/run-qemu.sh
> ssh -i ~/.ssh/id_medtech -p 2222 medadmin@localhost
> ```

**SCP file transfer:**
```bash
# Copy a file into the VM
scp -P 2222 localfile.txt medadmin@localhost:/tmp/

# Copy a file out of the VM
scp -P 2222 medadmin@localhost:/etc/medtech-release ./
```

---

## Step 4: Verify services

Inside the VM:

```bash
systemctl status mosquitto
systemctl status medtech-vitals-publisher
systemctl status medtech-edge-analytics
systemctl status medtech-clinician-ui
```

All four should show `active (running)`.

```bash
# Watch live MQTT data
mosquitto_sub -t "medtech/#" -v
```

---

## Step 5: Exit QEMU

```bash
# From inside the VM
shutdown -h now

# Or press Ctrl+A then X in the QEMU terminal
```

---

## Common Build Tasks

### Check image contents

```bash
# List all packages in the built image
cat yocto/build/tmp/deploy/images/qemuarm64/core-image-medtech-qemuarm64.manifest

# Check image size
ls -lh yocto/build/tmp/deploy/images/qemuarm64/core-image-medtech-qemuarm64.ext4
```

### Generate SBOM

```bash
bash scripts/generate-sbom.sh
# Output: sbom/sbom.json (CycloneDX 1.4 format)
```

### Package for release (creates the bundle.tar.gz)

```bash
bash scripts/package-release-artifacts.sh --image-name core-image-medtech
```

### Verify the package

```bash
bash scripts/verify-release-package.sh --image-name core-image-medtech
```

---

## Project Structure

```
medtech-device-os/
├── .devcontainer/           # Dev container configuration
├── .github/workflows/       # CI/CD pipeline
├── docs/                    # All documentation
├── scripts/                 # Build, test, and utility scripts
├── yocto/
│   ├── conf/                # Build configuration samples
│   └── meta-medtech/        # Custom Yocto layer
└── README.md
```

---

## Understanding the `bitbake` wrapper

The `scripts/bitbake` file is not the real BitBake binary — it's a wrapper that
handles privileges and environment setup automatically.

When you type `bitbake`, the wrapper:
1. Checks whether the build environment is initialized
2. If running as root, switches to the `builder` user (BitBake refuses root)
3. Sources `oe-init-build-env` to activate the Yocto environment
4. Executes the real BitBake with all your arguments

**You never need to think about this** — it just works.

---

## Troubleshooting builds

### Build fails with fetch errors

```bash
# Retry with verbose output
bitbake -v core-image-medtech

# Check connectivity
ping -c1 github.com
```

### Out of disk space

Check usage:
```bash
df -h
du -sh yocto/build/tmp/
rm -rf yocto/build/tmp/work/
```

See [../guides/disk-optimization.md](../guides/disk-optimization.md) for more strategies.

### Layer configuration broken

Reset to a clean state:
```bash
bash scripts/quick-setup.sh
```

---

## Next steps

- **Complete build options** → [../guides/build-guide.md](../guides/build-guide.md)
- **All commands** → [../reference/quick-reference.md](../reference/quick-reference.md)
- **Layer conventions** → [../reference/layer-structure.md](../reference/layer-structure.md)
- **Troubleshooting** → [../guides/deployment-troubleshooting.md](../guides/deployment-troubleshooting.md)
