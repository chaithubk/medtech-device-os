# meta-medtech — Custom Yocto Layer

This is the MedTech Device OS custom Yocto layer. It defines the medtech application
stack, system configuration, and the final image that runs on `qemuarm64`.

---

## Table of Contents

- [Overview](#overview)
- [Layer Metadata](#layer-metadata)
- [Directory Structure](#directory-structure)
- [Recipes](#recipes)
- [Adding a New Recipe](#adding-a-new-recipe)
- [Layer Dependencies](#layer-dependencies)
- [Compatibility](#compatibility)

---

## Overview

`meta-medtech` is the top-level custom Yocto layer for MedTech Device OS. It provides:

- **`core-image-medtech`** — the final bootable image definition
- **Medtech application services** — vitals publisher, edge analytics, clinician UI
- **Support packages** — Python MQTT client, TensorFlow Lite, Mosquitto customizations
- **System configuration** — base OS setup, release files, image policy class

---

## Layer Metadata

| Attribute | Value |
|---|---|
| Layer name | `meta-medtech` |
| BitBake priority | 6 (above OE layers at 5) |
| Yocto compatibility | kirkstone, langdale, scarthgap |
| Machine | `qemuarm64` (QEMU ARM64) |
| Distro | `poky` |

---

## Directory Structure

```
meta-medtech/
│
├── conf/
│   └── layer.conf               # Layer registration and dependency declarations
│
├── classes/
│   └── medtech-image.bbclass    # Shared image build policies (no debug pkgs)
│
├── recipes-core/
│   └── medtech-system/
│       └── medtech-system.bb    # Base OS config: /etc/medtech-release, core tweaks
│
├── recipes-image/
│   └── core-image-medtech/
│       └── core-image-medtech.bb  # Full image definition (IMAGE_INSTALL)
│
├── recipes-qt/                  # Qt6-specific configuration appends
│
├── recipes-services/            # Medtech application services
│   ├── medtech-vitals-publisher/
│   │   └── medtech-vitals-publisher_1.0.bb
│   ├── medtech-edge-analytics/
│   │   └── medtech-edge-analytics_1.0.bb
│   └── medtech-clinician-ui/
│       └── medtech-clinician-ui_1.0.bb
│
└── recipes-support/             # Third-party package recipes and appends
    ├── mosquitto/
    │   └── mosquitto_%.bbappend       # Mosquitto customization
    ├── python3-paho-mqtt/
    │   └── python3-paho-mqtt_1.6.1.bb # Python MQTT client
    └── tensorflow-lite/
        └── tensorflow-lite_2.14.0.bb  # TFLite for sepsis detection
```

---

## Recipes

### `medtech-system` (recipes-core)

Installs the base system configuration:
- `/etc/medtech-release` — build version, machine name, timestamp
- Any OS-level tweaks required by the medtech platform

### `core-image-medtech` (recipes-image)

The final image definition. Specifies the complete package list via `IMAGE_INSTALL`
and inherits `medtech-image.bbclass` for shared policies.

Key packages installed:
- `mosquitto` — MQTT broker
- `medtech-vitals-publisher` — patient vitals simulator
- `medtech-edge-analytics` — TFLite sepsis detection
- `medtech-clinician-ui` — Qt6 dashboard (headless)
- `openssh` — SSH server
- `medtech-system` — base system config

### `medtech-vitals-publisher` (recipes-services)

Python service that publishes simulated patient vitals to MQTT every 10 seconds.

- **Runtime deps:** `python3`, `python3-paho-mqtt`
- **MQTT topic:** `medtech/vitals/latest`
- **Systemd service:** auto-starts, restarts on failure

### `medtech-edge-analytics` (recipes-services)

TFLite-based service that subscribes to vitals and publishes sepsis risk scores.

- **Runtime deps:** `tensorflow-lite`, `python3`
- **MQTT input:** `medtech/vitals/latest`
- **MQTT output:** `medtech/predictions/sepsis`
- **Systemd service:** auto-starts after vitals publisher

### `medtech-clinician-ui` (recipes-services)

Qt6 dashboard that displays vitals and predictions. Runs headless/offscreen in QEMU.

- **Runtime deps:** Qt6 libraries
- **MQTT input:** `medtech/vitals/latest`, `medtech/predictions/sepsis`
- **Systemd service:** auto-starts after edge analytics

### `mosquitto_%.bbappend` (recipes-support)

Customizes the upstream Mosquitto build with options specific to the medtech platform.

### `python3-paho-mqtt_1.6.1.bb` (recipes-support)

Python MQTT client library. Not available in OE-Core; defined here for use
by the vitals publisher.

### `tensorflow-lite_2.14.0.bb` (recipes-support)

TensorFlow Lite 2.14.0 for ARM64. Used by the edge analytics service for
on-device ML inference.

---

## Adding a New Recipe

### 1. Choose the right category

| Category | Use for |
|---|---|
| `recipes-core` | Base system, OS config |
| `recipes-services` | Medtech application services |
| `recipes-support` | Third-party libraries and package customizations |
| `recipes-image` | Image definitions |

### 2. Create the recipe directory and file

```bash
mkdir -p recipes-services/medtech-my-service
```

```bitbake
# recipes-services/medtech-my-service/medtech-my-service_1.0.bb
DESCRIPTION = "MedTech my service"
LICENSE = "CLOSED"
LIC_FILES_CHKSUM = ""

SRC_URI = "file://my-service.py \
           file://medtech-my-service.service \
          "

RDEPENDS:${PN} = "python3 python3-paho-mqtt"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/my-service.py ${D}${bindir}/my-service

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/medtech-my-service.service \
        ${D}${systemd_system_unitdir}/medtech-my-service.service
}

inherit systemd
SYSTEMD_SERVICE:${PN} = "medtech-my-service.service"
SYSTEMD_AUTO_ENABLE = "enable"
```

### 3. Add source files to the recipe directory

### 4. Add to the image

Edit `recipes-image/core-image-medtech/core-image-medtech.bb`:
```bitbake
IMAGE_INSTALL:append = " medtech-my-service"
```

### 5. Build and test

```bash
bitbake medtech-my-service
bitbake core-image-medtech
```

For detailed recipe writing guidance, see [docs/RECIPES.md](../../docs/RECIPES.md).

---

## Layer Dependencies

Declared in `conf/layer.conf`:

| Layer | Package | Why needed |
|---|---|---|
| `core` | Poky/OE-Core | Base Linux, kernel, systemd, Python3, OpenSSH |
| `openembedded-layer` | meta-oe | Mosquitto, extended Python packages |
| `networking-layer` | meta-networking | Network tools and socket libraries |
| `qt6-layer` | meta-qt6 | Qt6 framework for medtech-clinician-ui |

---

## Compatibility

This layer is tested with:
- **kirkstone** — current production release (LTS)
- **langdale** — forward compatibility
- **scarthgap** — next LTS (migration path)

When upgrading the Yocto release:
1. Test all recipes build cleanly
2. Update `LAYERSERIES_COMPAT_meta-medtech` in `conf/layer.conf`
3. Check for API changes in affected recipes
4. Update CI workflow clone commands to use the new branch name
