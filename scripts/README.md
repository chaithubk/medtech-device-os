# Scripts Guide

## Build Scripts

### `build.sh`
**Quick local build** for development iteration.
- Initializes Yocto environment in one step
- Adds local workarounds for Qt/network issues
- Suitable for: testing recipe changes, quick iterations

**Usage:**
```bash
bash scripts/build.sh
```

### `build-robust.sh`
**Production-grade build** with full diagnostics and error recovery.
- Runs pre-flight checks → clones layers with retry → builds with diagnostics
- Collects disk usage, compiler versions, failed task logs
- Same workflow as CI pipeline
- Suitable for: final validation before CI push, reproducible builds, troubleshooting

**Usage:**
```bash
bash scripts/build-robust.sh
```

---

## Run & Test Scripts

### `run-qemu.sh`
**Boot the built image in QEMU ARM64 emulator** for testing.
- Validates kernel and rootfs exist
- Launches qemu-system-aarch64 with proper device configuration
- SSH available on localhost:2222
- Suitable for: sanity checks inside QEMU, testing services

**Inside QEMU terminal console:**
```bash
# Login: root
# Password: root
systemctl status mosquitto
systemctl status medtech-vitals-publisher
mosquitto_sub -t "medtech/#" -v
```

**SSH into QEMU from host** (port 2222):
```bash
ssh -p 2222 root@localhost
# Password: root
```

**Usage:**
```bash
bash scripts/run-qemu.sh              # nographic (terminal mode)
bash scripts/run-qemu.sh --graphics   # with GUI
```

### `run-ghcr-qemu.sh`
**Pull a GHCR image, extract Yocto artifacts, and boot it in QEMU on a host Ubuntu machine.**
- Pulls an image like `ghcr.io/<owner>/<repo>/qemu-image:<tag>`
- Tries `/artifacts` first, then auto-discovers `.ext4`, `Image*`, and `.dtb` paths in the container
- Boots `qemu-system-aarch64` with SSH forwarded to `localhost:2222`
- Suitable for: running CI-published image artifacts outside the dev container

**Usage:**
```bash
bash scripts/run-ghcr-qemu.sh --image ghcr.io/<owner>/<repo>/qemu-image:latest
bash scripts/run-ghcr-qemu.sh --image ghcr.io/<owner>/<repo>/qemu-image:main --graphics
```

If the GHCR image contains only `.ext4` and no kernel artifact, provide kernel path explicitly:
```bash
bash scripts/run-ghcr-qemu.sh \
	--image ghcr.io/<owner>/<repo>/qemu-image:latest \
	--kernel /path/to/Image-qemuarm64.bin
```

**If pull returns `unauthorized`:**
```bash
export GHCR_PAT=<token-with-read:packages>
echo "$GHCR_PAT" | docker login ghcr.io -u <github-username> --password-stdin
```

If your package is under an organization, ensure the token is SSO-authorized for that org.

**Helpful options:**
```bash
# Just resolve artifacts and print the QEMU command
bash scripts/run-ghcr-qemu.sh --image ghcr.io/<owner>/<repo>/qemu-image:latest --dry-run

# Keep extracted artifacts after QEMU exits
bash scripts/run-ghcr-qemu.sh --image ghcr.io/<owner>/<repo>/qemu-image:latest --keep

# Override rootfs/dtb manually if needed
bash scripts/run-ghcr-qemu.sh --image ghcr.io/<owner>/<repo>/qemu-image:latest --rootfs /path/to/rootfs.ext4 --dtb /path/to/qemuarm64.dtb
```

### `test-qemu.sh`
Automated test script that SSH's into the running QEMU image and verifies services.
- Waits for SSH daemon to start (up to 60 seconds)
- Checks system info, running services, MQTT topics
- Suitable for: validating full boot without manual SSH

**Usage:**
```bash
bash scripts/test-qemu.sh
```

---

## Setup & Validation Scripts

### `setup-host-qemu-prereqs.sh`
**Prepare a plain Ubuntu host to run GHCR-published QEMU artifacts.**
- Installs Docker and QEMU host packages
- Enables/starts Docker service
- Verifies Docker daemon and `qemu-system-aarch64`
- Suitable for: first-time setup on laptops/VMs outside the dev container

**Usage:**
```bash
bash scripts/setup-host-qemu-prereqs.sh
```

**Optional flags:**
```bash
# Only validate existing installation
bash scripts/setup-host-qemu-prereqs.sh --no-install

# Add current user to docker group (re-login required)
bash scripts/setup-host-qemu-prereqs.sh --add-docker-group
```

### `setup-devenv.sh`
Initializes the dev environment (host tools, Yocto layers).

### `quick-setup.sh`
Lightweight setup (assumes Yocto layers already present).

### `preflight-check.sh`
Validates host tools and prerequisites (called by `build-robust.sh`).

### `clone-with-retry.sh`
Clones Yocto layers with retry logic and mirror fallback (called by `build-robust.sh`).

### `generate-sbom.sh`
Generates CycloneDX SBOM from the built image.

### `process-sbom.sh`
Post-processes SBOM for validation.

### `verify-image.sh`
Sanity checks on the final rootfs image.

### `audit-image-deps.sh`
Dependency-closure audit for an image target (dry-run, no full compile).
- Generates `pn-buildlist` and `task-depends.dot`
- Captures resolved `IMAGE_INSTALL`, `CORE_IMAGE_BASE_INSTALL`, and feature variables
- Flags common bloat candidates (packagegroups, ptest/test stacks)
- Extracts direct service `RDEPENDS` from `meta-medtech/recipes-services`

**Usage:**
```bash
su - builder -c 'cd /workspace && bash scripts/audit-image-deps.sh core-image-medtech'
```

---

## Recommended Workflow

### Local Development
1. **Build:** `bash scripts/build.sh`
2. **Test:** `bash scripts/run-qemu.sh`
3. **Iterate:** Edit recipe → `bash scripts/build.sh` → test

### Run CI Image On Ubuntu Host
1. **Prepare host:** `bash scripts/setup-host-qemu-prereqs.sh`
2. **Run GHCR image:** `bash scripts/run-ghcr-qemu.sh --image ghcr.io/<owner>/<repo>/qemu-image:latest`

### Before CI Push
1. **Full validation:** `bash scripts/build-robust.sh`
2. **Generate SBOM:** `bash scripts/generate-sbom.sh`
3. **Verify image:** `bash scripts/verify-image.sh`
4. **Final test:** `bash scripts/run-qemu.sh`

### CI Pipeline
Same as "Before CI Push" (automated in `.github/workflows/device-build-smart.yml`).
