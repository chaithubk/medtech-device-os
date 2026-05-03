# Quick Start: Running MedTech Device OS

> **Goal:** Download and boot the latest MedTech Device OS release in QEMU in under 5 minutes.

---

## Prerequisites

- Ubuntu 22.04 (or compatible) — native, VM, or WSL2
- ~1 GB free disk space for the download
- No Docker required

### One-time setup (first use only)

Install QEMU for ARM64 emulation:

```bash
bash scripts/setup-host-qemu-prereqs.sh
```

This installs `qemu-system-aarch64` and verifies the installation. You only need to do this once.

---

## Step 1: Download and boot the latest release

```bash
bash scripts/download-and-run-qemu.sh
```

The script will:
1. Fetch the latest release from GitHub
2. Download the kernel, rootfs, and checksums
3. Verify all SHA256 checksums
4. Boot QEMU and display a status box
5. **Automatically wait for SSH to become ready** (up to 60 seconds)

Expected output:

```
=== Fetching release metadata ===
Resolved tag: latest
=== Downloading release assets ===
  Downloading bundle ...
  Downloading manifest ...
  Downloading SHA256SUMS ...
=== Verifying SHA256 checksums ===
Checksum verification passed.
=== Extracting bundle ===
=== Resolving artifacts ===
  Kernel : /path/to/Image-qemuarm64.bin
  Rootfs : /path/to/core-image-medtech-qemuarm64.ext4
  DTB    : <none>

┌─────────────────────────────────────────────────────────────┐
│               MedTech Device OS — QEMU Boot                 │
├─────────────────────────────────────────────────────────────┤
│  Default Credentials                                         │
│    Username : root                                           │
│    Password : root                                           │
├─────────────────────────────────────────────────────────────┤
│  Access Methods                                              │
│    SSH  : ssh -p 2222 root@localhost                         │
└─────────────────────────────────────────────────────────────┘

=== Booting QEMU ===
Waiting for SSH daemon on 127.0.0.1:2222 ...
  ✓ SSH port is open (daemon is up)

Connect now:
  ssh -p 2222 root@localhost
  (password: root)
```

---

## Step 2: Connect via SSH

Once the script shows "SSH daemon is responding":

```bash
ssh -p 2222 root@localhost
# Password: root
```

You are now inside the MedTech Device OS running in QEMU.

---

## Step 3: Verify services

Inside the QEMU system, run:

```bash
# Check all medtech services are running
systemctl status mosquitto
systemctl status medtech-vitals-publisher
systemctl status medtech-edge-analytics
systemctl status medtech-clinician-ui
```

Expected: all four show `active (running)`.

```bash
# Verify MQTT data flow (Ctrl+C to stop)
mosquitto_sub -t "medtech/#" -v
```

You should see live data like:
```
medtech/vitals/latest {"heart_rate": 75, "spo2": 98, ...}
medtech/predictions/sepsis {"risk": 0.12, "alert": false}
```

---

## Step 4: Exit QEMU

From the SSH session:
```bash
shutdown -h now
```

Or press **Ctrl+A then X** in the QEMU terminal window.

---

## Common Options

### Run a specific release version

```bash
bash scripts/download-and-run-qemu.sh --release v1.2.3
```

### Use direct serial console (instead of SSH)

```bash
bash scripts/download-and-run-qemu.sh --console
```

This attaches your terminal directly to the QEMU serial console — useful when SSH is not yet working or you want to see the full boot log.

### Skip SSH wait (for automation/CI)

```bash
bash scripts/download-and-run-qemu.sh --no-wait-ssh
```

### Increase VM memory

```bash
bash scripts/download-and-run-qemu.sh --memory 512
```

### Keep downloaded artifacts after exit

```bash
bash scripts/download-and-run-qemu.sh --keep
```

---

## Transfer files into/out of the VM

### Copy a file into the VM:
```bash
scp -P 2222 myfile.txt root@localhost:/tmp/
```

### Copy a file out of the VM:
```bash
scp -P 2222 root@localhost:/var/log/syslog ./
```

---

## What's included in each release

Each GitHub Release contains:

| File | Description |
|---|---|
| `*-bundle.tar.gz` | Kernel image, root filesystem, optional DTB |
| `*-manifest.json` | Build metadata and per-file checksums |
| `SHA256SUMS` | Checksum file for integrity verification |

---

## Troubleshooting

**SSH connection refused after boot:**
→ See [DEPLOYMENT_TROUBLESHOOTING.md](DEPLOYMENT_TROUBLESHOOTING.md)

**QEMU shows black screen / no output:**
→ Use `--console` flag for serial console access

**Download fails with rate limit error:**
→ Set a GitHub token: `export GITHUB_TOKEN=<your_token>`

**"Missing required command: qemu-system-aarch64":**
→ Run `bash scripts/setup-host-qemu-prereqs.sh` first

---

## Next steps

- **Copy-paste commands** → [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
- **Troubleshooting guide** → [DEPLOYMENT_TROUBLESHOOTING.md](DEPLOYMENT_TROUBLESHOOTING.md)
- **Build from source** → [QUICK_START_DEVELOPER.md](QUICK_START_DEVELOPER.md)
