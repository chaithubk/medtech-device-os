# MedTech Device OS — Quick Reference

All the common commands in one place. Copy and paste as needed.

---

## Setup (one-time)

```bash
# Install QEMU on Ubuntu (for running releases — no Docker)
bash scripts/setup-host-qemu-prereqs.sh
```

---

## Running Releases (no build required)

```bash
# Download and boot the latest release
bash scripts/download-and-run-qemu.sh

# Boot a specific release version
bash scripts/download-and-run-qemu.sh --release v1.2.3

# Boot with direct serial console (see full boot log)
bash scripts/download-and-run-qemu.sh --console

# Boot without waiting for SSH (CI/automation use)
bash scripts/download-and-run-qemu.sh --no-wait-ssh

# Boot with more memory (default: 256 MB)
bash scripts/download-and-run-qemu.sh --memory 512

# Keep downloaded files after exit
bash scripts/download-and-run-qemu.sh --keep

# Preview QEMU command without booting
bash scripts/download-and-run-qemu.sh --dry-run
```

---

## SSH Access

```bash
# Connect to running QEMU VM
ssh -p 2222 root@localhost
# Password: root

# Copy file into VM
scp -P 2222 localfile.txt root@localhost:/tmp/

# Copy file from VM
scp -P 2222 root@localhost:/var/log/syslog ./

# Remove stale host key (when switching releases)
ssh-keygen -R "[localhost]:2222"
```

---

## Service Management (inside VM)

```bash
# Check all medtech services
systemctl status mosquitto
systemctl status medtech-vitals-publisher
systemctl status medtech-edge-analytics
systemctl status medtech-clinician-ui

# Restart a service
systemctl restart medtech-vitals-publisher

# View service logs
journalctl -u medtech-vitals-publisher -n 50
journalctl -u medtech-vitals-publisher -f  # live tail

# Watch all services
watch -n2 systemctl status mosquitto medtech-vitals-publisher medtech-edge-analytics medtech-clinician-ui
```

---

## MQTT Verification (inside VM)

```bash
# Subscribe to all medtech topics (live data stream)
mosquitto_sub -t "medtech/#" -v

# Subscribe to vitals only
mosquitto_sub -t "medtech/vitals/latest" -v

# Subscribe to sepsis predictions
mosquitto_sub -t "medtech/predictions/sepsis" -v

# Publish a test message
mosquitto_pub -t "test/ping" -m "hello"
```

---

## Image Metadata (inside VM)

```bash
# Check image version and build info
cat /etc/medtech-release

# Check OS release
cat /etc/os-release

# List installed packages
opkg list-installed 2>/dev/null | head -n 20
```

---

## Exit QEMU

```bash
# From SSH session inside VM
shutdown -h now

# From QEMU serial console
# Press: Ctrl+A then X
```

---

## Developer: Build from Source

```bash
# Open dev container in VS Code
# Ctrl+Shift+P → "Dev Containers: Reopen in Container"

# Build the full image (in container terminal)
bitbake core-image-medtech

# Build a single recipe
bitbake medtech-vitals-publisher

# Force clean rebuild of a recipe
bitbake -c cleansstate medtech-vitals-publisher && bitbake medtech-vitals-publisher

# Boot locally-built image
bash scripts/run-qemu.sh

# Package artifacts for release
bash scripts/package-release-artifacts.sh --image-name core-image-medtech

# Verify the package
bash scripts/verify-release-package.sh --image-name core-image-medtech

# Generate SBOM
bash scripts/generate-sbom.sh
```

---

## Developer: Disk Management (in container)

```bash
# Check disk usage
df -h

# Check build tree size
du -sh yocto/build/tmp/

# Free up work directories (safe to delete, will be rebuilt)
rm -rf yocto/build/tmp/work/
rm -rf yocto/build/tmp/work-shared/
rm -rf yocto/sstate-cache/

# Audit build dependencies (no compile)
su - builder -c 'cd /workspace && bash scripts/audit-image-deps.sh core-image-medtech'
```

---

## GitHub Token (for private repos / rate limits)

```bash
# Set a GitHub token for downloads
export GITHUB_TOKEN=ghp_your_token_here
bash scripts/download-and-run-qemu.sh

# Or use gh CLI (recommended)
gh auth login
bash scripts/download-and-run-qemu.sh
```

---

## CI Debugging

```bash
# View CI workflow file
cat .github/workflows/device-build-smart.yml

# Check what CI runs (preflight parse)
bitbake -p

# Check URI for specific recipe
bitbake medtech-vitals-publisher -c checkuri
```

---

## Useful Paths (inside VM)

| Path | Contents |
|---|---|
| `/etc/medtech-release` | Image version |
| `/etc/systemd/system/` | Systemd service files |
| `/usr/bin/vitals-publisher` | Vitals publisher binary/script |
| `/usr/bin/edge-analytics` | Edge analytics binary |
| `/var/log/` | System logs |

## Useful Paths (in container)

| Path | Contents |
|---|---|
| `/workspace/yocto/meta-medtech/` | Custom layer |
| `/workspace/yocto/build/tmp/deploy/images/qemuarm64/` | Built images |
| `/workspace/yocto/build/tmp/work/` | Recipe work directories |
| `/workspace/artifacts/` | Packaged release bundle |
| `/workspace/sbom/` | Generated SBOM |
