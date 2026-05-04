# Architecture: MedTech Device OS

System design overview, component relationships, and data flows.

---

## Table of Contents

- [System Overview](#system-overview)
- [Target Platform](#target-platform)
- [Component Architecture](#component-architecture)
- [MQTT Data Flow](#mqtt-data-flow)
- [Systemd Service Dependency Chain](#systemd-service-dependency-chain)
- [Build System Architecture](#build-system-architecture)
- [Deployment Architecture](#deployment-architecture)
- [Network Architecture (QEMU)](#network-architecture-qemu)

---

## System Overview

MedTech Device OS is an embedded Linux operating system for medical IoT devices.
It is built using the Yocto Project and targets an ARM64 architecture (emulated
via QEMU for development and testing).

The OS provides a complete medtech application stack:
- **MQTT broker** for device communication
- **Vitals publisher** for patient data simulation
- **Edge analytics** for real-time sepsis risk scoring
- **Clinician UI** for data visualization

All components are packaged as systemd services and managed through the OS
lifecycle.

---

## Target Platform

| Attribute | Value |
|---|---|
| Architecture | ARM64 (aarch64) |
| Yocto machine | `qemuarm64` |
| Yocto release | kirkstone (LTS) |
| CPU emulated | Cortex-A57 (4 cores) |
| Memory (QEMU) | 256 MB (configurable) |
| Root filesystem | ext4, ~512 MB |
| Kernel | Linux (from Poky kirkstone) |
| Init system | systemd |

---

## Component Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  MedTech Device OS (ARM64)                   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                Application Layer                      │   │
│  │                                                       │   │
│  │  ┌─────────────────┐   ┌──────────────────────────┐  │   │
│  │  │ Vitals Publisher│   │    Edge Analytics         │  │   │
│  │  │   (Python 3)    │   │  (TensorFlow Lite 2.14)   │  │   │
│  │  │ Publishes every │   │  Sepsis risk scoring      │  │   │
│  │  │ 10 seconds      │   │  (ML inference)           │  │   │
│  │  └────────┬────────┘   └───────────┬──────────────┘  │   │
│  │           │ medtech/vitals/latest   │ medtech/predictions │
│  │           ▼                         ▼                  │   │
│  │  ┌─────────────────────────────────────────────────┐  │   │
│  │  │              Mosquitto MQTT Broker               │  │   │
│  │  │              (Port 1883, local only)             │  │   │
│  │  └─────────────────────────────────────────────────┘  │   │
│  │           │                         │                  │   │
│  │           ▼                         ▼                  │   │
│  │  ┌────────────────┐   ┌─────────────────────────────┐ │   │
│  │  │  Clinician UI  │   │         SSH Server           │ │   │
│  │  │    (Qt6)       │   │  (port 22 → host port 2222)  │ │   │
│  │  │  Headless/     │   │                              │ │   │
│  │  │  offscreen     │   │                              │ │   │
│  │  └────────────────┘   └─────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              OS Layer (Yocto/Poky kirkstone)          │   │
│  │  systemd • busybox • Python 3 • OpenSSH               │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## MQTT Data Flow

```
Topic: medtech/vitals/latest
────────────────────────────
Vitals Publisher ──publish──→ Mosquitto Broker ──subscribe──→ Edge Analytics
   (Python 3)                   (port 1883)                   (TFLite)
   Every 10 seconds

Payload example:
{
  "heart_rate": 75,
  "spo2": 98,
  "blood_pressure_systolic": 120,
  "blood_pressure_diastolic": 80,
  "temperature": 37.1,
  "timestamp": "2024-01-15T10:30:00Z"
}

Topic: medtech/predictions/sepsis
──────────────────────────────────
Edge Analytics ──publish──→ Mosquitto Broker ──subscribe──→ Clinician UI
  (TFLite inference)           (port 1883)                   (Qt6)

Payload example:
{
  "risk": 0.12,
  "alert": false,
  "model_version": "2.14.0",
  "timestamp": "2024-01-15T10:30:02Z"
}
```

---

## Systemd Service Dependency Chain

Services start in this order (systemd enforces ordering):

```
mosquitto.service                    [starts first — MQTT broker]
  └── medtech-vitals-publisher.service   [needs broker to publish]
        └── medtech-edge-analytics.service   [needs vitals stream]
              └── medtech-clinician-ui.service   [needs predictions]
```

The dependency chain ensures that:
1. The MQTT broker is always available before application services start
2. Services fail gracefully if their dependency is unavailable
3. Systemd restarts failed services automatically (`Restart=on-failure`)

---

## Build System Architecture

```
Host (Ubuntu 22.04)
└── Dev Container (Docker)
    └── /workspace
        ├── scripts/bitbake  ← wrapper (root→builder, env setup)
        ├── yocto/
        │   ├── poky/           ← Yocto/Poky (kirkstone)
        │   ├── meta-openembedded/  ← OE layers
        │   ├── meta-qt6/       ← Qt6 layer
        │   ├── meta-medtech/   ← our custom layer
        │   ├── conf/           ← sample configs (tracked in git)
        │   └── build/          ← generated build dir (not tracked)
        │       ├── conf/
        │       │   ├── bblayers.conf (generated from sample)
        │       │   └── local.conf    (generated from sample)
        │       └── tmp/
        │           └── deploy/images/qemuarm64/
        │               ├── core-image-medtech-qemuarm64.ext4
        │               └── Image-qemuarm64.bin
        └── artifacts/          ← packaged release bundle
            ├── *-bundle.tar.gz
            ├── *-manifest.json
            └── SHA256SUMS
```

---

## Deployment Architecture

```
GitHub Actions CI
  │
  ├── Build: bitbake core-image-medtech
  ├── Package: package-release-artifacts.sh
  ├── Verify: verify-release-package.sh
  └── Release: GitHub Release
                │
                └── GitHub Releases page
                          │
                          └── download-and-run-qemu.sh
                                    │
                                    ├── Download bundle.tar.gz
                                    ├── Verify SHA256SUMS
                                    ├── Extract artifacts
                                    └── Boot QEMU
                                              │
                                              └── Running VM
                                                    │
                                                    └── SSH: localhost:2222
```

---

## Network Architecture (QEMU)

QEMU uses user-mode networking with port forwarding. Only SSH (port 22) is
forwarded to the host by default:

```
Host machine
└── Port 2222 ──→ QEMU VM: Port 22 (SSH)

Inside QEMU VM (not exposed to host by default):
├── 127.0.0.1:22    → OpenSSH
├── 127.0.0.1:1883  → Mosquitto (MQTT)
└── 10.0.2.x        → Default QEMU NAT gateway
```

To expose additional ports (e.g. MQTT broker for testing), add `hostfwd` rules
to the QEMU command's `-netdev` option:

```bash
# Example: forward host:1883 → VM:1883
-netdev "user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22,hostfwd=tcp:127.0.0.1:1883-:1883"
```

QEMU MAC address: `52:54:00:12:34:02` (fixed, for reproducibility).

The QEMU network uses SLIRP/user-mode networking (no root required, no bridge
setup). The VM can reach the internet through the host NAT. Inbound connections
from the host to the VM use the port forwarding rules above.
