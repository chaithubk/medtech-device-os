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
# Login: root (no password)
systemctl status mosquitto
systemctl status medtech-vitals-publisher
mosquitto_sub -t "medtech/#" -v
```

**SSH into QEMU from host** (port 2222):
```bash
ssh -p 2222 root@localhost
# Password: (press Enter — root has no password)
```

**Usage:**
```bash
bash scripts/run-qemu.sh              # nographic (terminal mode)
bash scripts/run-qemu.sh --graphics   # with GUI
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

---

## Recommended Workflow

### Local Development
1. **Build:** `bash scripts/build.sh`
2. **Test:** `bash scripts/run-qemu.sh`
3. **Iterate:** Edit recipe → `bash scripts/build.sh` → test

### Before CI Push
1. **Full validation:** `bash scripts/build-robust.sh`
2. **Generate SBOM:** `bash scripts/generate-sbom.sh`
3. **Verify image:** `bash scripts/verify-image.sh`
4. **Final test:** `bash scripts/run-qemu.sh`

### CI Pipeline
Same as "Before CI Push" (automated in `.github/workflows/device-build-smart.yml`).
