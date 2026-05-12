# Quick Reference — Common Commands

All common commands in one place.

---

## Setup (one-time)

```bash
# Install QEMU on Ubuntu (for running releases — no Docker)
bash scripts/setup-host-qemu-prereqs.sh
```

---

## Running Releases

```bash
# Download and boot the latest release
bash scripts/download-and-run-qemu.sh

# Boot a specific release version
bash scripts/download-and-run-qemu.sh --release v1.2.3

# Boot with direct serial console
bash scripts/download-and-run-qemu.sh --console

# Boot without waiting for SSH (CI/automation)
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
ssh -p 2222 medadmin@localhost

# Copy file into VM
scp -P 2222 localfile.txt medadmin@localhost:/tmp/

# Copy file from VM
scp -P 2222 medadmin@localhost:/var/log/syslog ./

# Remove stale host key
ssh-keygen -R "[localhost]:2222"
```

SSH password auth is disabled.
For local builds, provision `.secrets/medtech-admin-key.pub` before building.
For public-hardened release artifacts, no default admin SSH key is baked.

---

## Service Management (inside VM)

```bash
# Check all medtech services
systemctl status mosquitto medtech-vitals-publisher medtech-edge-analytics medtech-clinician-ui

# Restart a service
systemctl restart medtech-vitals-publisher

# View service logs
journalctl -u medtech-vitals-publisher -n 50
journalctl -u medtech-vitals-publisher -f  # live tail
```

---

## MQTT Verification (inside VM)

```bash
# Subscribe to all medtech topics
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

# From QEMU serial console: Ctrl+A then X
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

# Generate SBOM
bash scripts/generate-sbom.sh
# Collects SPDX outputs into sbom/
```

---

## Developer: Disk Management

```bash
# Check disk usage
df -h

# Check build tree size
du -sh yocto/build/tmp/

# Free up work directories (safe to delete, will be rebuilt)
rm -rf yocto/build/tmp/work/
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
