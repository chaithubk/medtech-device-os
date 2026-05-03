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
   - This clones the Yocto layers (poky, meta-openembedded, meta-qt6) — takes ~2 minutes on first run.
   - Subsequent opens are instant (layers are already present).

5. Wait for the "postCreateCommand" to complete in the VS Code terminal.

---

## Step 2: Build the image

Open a terminal in VS Code (`Ctrl+`` `) and run:

```bash
bitbake core-image-medtech
```

That's it. The `bitbake` wrapper automatically:
- Drops privileges from root to the `builder` user (BitBake requires non-root)
- Sources the Yocto build environment
- Runs the full image build

> **First build takes 60–120 minutes** as it compiles everything from source.
> Subsequent builds with unchanged recipes take a few minutes (sstate cache).

### What you'll see during the build

```
Loading cache: 100% |########| Time: 0:00:02
Loaded 1234 entries from dependency cache.
NOTE: Resolving any missing task queue dependencies

Build Configuration:
BB_VERSION           = "2.0.0"
BUILD_SYS            = "x86_64-linux"
TARGET_SYS           = "aarch64-poky-linux"
MACHINE              = "qemuarm64"
DISTRO               = "poky"
...

Initialising tasks: 100% |########| Time: 0:00:05
Sstate summary: ...
NOTE: Executing Tasks
...
NOTE: Tasks Summary: ...
```

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

**Default login:**
- Username: `root`
- Password: `root`

**SSH from another terminal on your host:**
```bash
ssh -p 2222 root@localhost
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
│   ├── Dockerfile           # Container image definition
│   └── devcontainer.json    # VS Code dev container settings
├── .github/workflows/       # CI/CD pipeline
│   └── device-build-smart.yml
├── docs/                    # All documentation
├── scripts/                 # Build, test, and utility scripts
│   ├── bitbake              # BitBake wrapper (root→builder, env setup)
│   ├── build.sh             # Quick local build
│   ├── run-qemu.sh          # Boot locally-built image
│   └── download-and-run-qemu.sh  # Download & run GitHub Release
├── yocto/
│   ├── conf/                # CI bblayers.conf.sample and local.conf.sample
│   └── meta-medtech/        # Custom Yocto layer
│       ├── conf/layer.conf
│       ├── classes/
│       └── recipes-*/       # All custom recipes
└── README.md
```

---

## Understanding the `bitbake` wrapper

The `scripts/bitbake` file is not the real BitBake binary — it's a wrapper script
that lives in `/workspace/scripts/`, which is prepended to `PATH` in the container.

When you type `bitbake`, the wrapper:
1. Checks whether the build environment is initialized (bblayers.conf exists, layers are present)
2. If not, runs `quick-setup.sh` automatically
3. If running as root, switches to the `builder` user (BitBake refuses root)
4. Sources `oe-init-build-env` to activate the Yocto environment
5. Executes the real BitBake with all your arguments

**You never need to think about this** — it just works. See `scripts/bitbake` for the implementation.

---

## Troubleshooting builds

### "Do not use Bitbake as root"

This should never happen with the wrapper. If it does:
```bash
# Check who you are
id
# Switch to builder manually
su - builder
cd /workspace
source yocto/poky/oe-init-build-env yocto/build
bitbake core-image-medtech
```

### Build fails with fetch errors

```bash
# Retry with verbose output
bitbake -v core-image-medtech

# Check connectivity
ping -c1 github.com

# Clear download cache for a specific recipe
bitbake -c cleanall medtech-vitals-publisher
bitbake medtech-vitals-publisher
```

### Out of disk space

Check usage:
```bash
df -h
du -sh yocto/build/tmp/
```

Clean work directories:
```bash
rm -rf yocto/build/tmp/work/
```

See [DISK_OPTIMIZATION.md](DISK_OPTIMIZATION.md) for more strategies.

### Layer configuration broken

Reset to a clean state:
```bash
bash scripts/quick-setup.sh
```

---

## Next steps

- **Complete build options** → [BUILD_GUIDE.md](BUILD_GUIDE.md)
- **Layer and recipe conventions** → [LAYER_STRUCTURE.md](LAYER_STRUCTURE.md)
- **Adding new recipes** → [RECIPES.md](RECIPES.md)
- **CI/CD pipeline** → [CI_CD.md](CI_CD.md)
