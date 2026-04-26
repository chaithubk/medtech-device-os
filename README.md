# MedTech Device OS

Embedded Linux operating system for medical IoT devices using Yocto Project (kirkstone).

## Stage 1: QEMU Emulation

### Features

- ✅ Yocto/Poky kirkstone build system
- ✅ `core-image-medtech` custom image
- ✅ **MQTT Broker** (Mosquitto) – auto-starts on boot
- ✅ **Vitals Publisher** – publishes simulated patient vitals every 10 s
- ✅ **Edge Analytics** – TensorFlow Lite sepsis detection
- ✅ **Clinician UI** – Qt6 dashboard (headless/offscreen for QEMU)
- ✅ Systemd service management with proper dependency chain
- ✅ CycloneDX SBOM generation
- ✅ QEMU ARM64 emulator
- ✅ SSH server
- ✅ CI/CD via GitHub Actions → GHCR

### Architecture

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

### Quick Start

#### Build in Dev Container

```bash
# Reopen folder in container
# Cmd+Shift+P → Dev Containers: Reopen in Container

# Initialize Yocto (first time only – clones poky + meta-openembedded)
bash scripts/quick-setup.sh

# Build MedTech image (30–90 minutes first build)
source yocto/poky/oe-init-build-env yocto/build
cp yocto/conf/local.conf.sample conf/local.conf
cp yocto/conf/bblayers.conf.sample conf/bblayers.conf
bitbake core-image-medtech
```

#### Boot in QEMU

```bash
# From the yocto/build directory
runqemu qemuarm64 core-image-medtech nographic

# Login: root  (no password)
```

---

### Sanity Checks Inside QEMU

After booting, log in as `root` and run the following checks:

#### 1. Check all services are running

```bash
systemctl status mosquitto
systemctl status medtech-vitals-publisher
systemctl status medtech-edge-analytics
systemctl status medtech-clinician-ui
```

Expected: all four services show `active (running)`.

#### 2. Verify MQTT data flow

Open two terminals (or use `tmux`/`screen`):

```bash
# Terminal 1 – subscribe to all medtech topics
mosquitto_sub -t "medtech/#" -v

# Terminal 2 – wait ~10 seconds; you should see output like:
# medtech/vitals/latest {"heart_rate": 75, "spo2": 98, ...}
# medtech/predictions/sepsis {"risk": 0.12, "alert": false}
```

#### 3. Inspect service logs

```bash
journalctl -u medtech-vitals-publisher -n 50
journalctl -u medtech-edge-analytics   -n 50
journalctl -u medtech-clinician-ui     -n 50
```

#### 4. Verify image metadata

```bash
cat /etc/medtech-release
```

#### 5. Exit QEMU

```bash
# Press Ctrl+A then X
# or
shutdown -h now
```

---

### Generate SBOM

```bash
bash scripts/generate-sbom.sh
# Output: sbom/sbom.json  (CycloneDX 1.4 format)
```

### SSH into QEMU

```bash
ssh -p 2222 root@localhost
```

### CI/CD

GitHub Actions (`.github/workflows/device-build.yml`) automatically:
1. Validates the layer structure
2. Builds `core-image-medtech` with BitBake
3. Generates and validates the CycloneDX SBOM
4. Uploads the `.ext4` image and SBOM as artifacts
5. Pushes a tagged Docker image to GHCR (`ghcr.io/<owner>/medtech-device-os/qemu-image`)

### Layer Structure

```
yocto/meta-medtech/
├── conf/layer.conf
├── classes/medtech-image.bbclass
├── recipes-core/medtech-system/medtech-system.bb
├── recipes-services/
│   ├── medtech-vitals-publisher/medtech-vitals-publisher_1.0.bb
│   ├── medtech-edge-analytics/medtech-edge-analytics_1.0.bb
│   └── medtech-clinician-ui/medtech-clinician-ui_1.0.bb
├── recipes-support/
│   ├── mosquitto/mosquitto_%.bbappend
│   ├── python3-paho-mqtt/python3-paho-mqtt_1.6.1.bb
│   └── tensorflow-lite/tensorflow-lite_2.14.0.bb
└── recipes-image/core-image-medtech/core-image-medtech.bb
```
