# Layer Structure: meta-medtech

This document describes the organization of the `meta-medtech` custom Yocto layer,
explains recipe conventions, and provides a guide for adding new service recipes.

---

## Table of Contents

- [Layer Overview](#layer-overview)
- [Directory Structure](#directory-structure)
- [Layer Configuration](#layer-configuration)
- [Recipe Categories](#recipe-categories)
- [Recipe Naming Conventions](#recipe-naming-conventions)
- [Adding a New Service Recipe](#adding-a-new-service-recipe)
- [Systemd Service File Pattern](#systemd-service-file-pattern)
- [Versioning Strategy](#versioning-strategy)
- [Layer Dependencies](#layer-dependencies)

---

## Layer Overview

`meta-medtech` is the top-level custom Yocto layer for MedTech Device OS. It contains:
- The final image definition (`core-image-medtech`)
- All medtech-specific service recipes
- Support recipes for third-party packages (mosquitto, Python packages, TFLite)
- Custom image class (`medtech-image.bbclass`)

The layer sits at priority 6, above the default OpenEmbedded layers (priority 5),
so its `.bbappend` files and overrides take precedence.

---

## Directory Structure

```
yocto/meta-medtech/
│
├── conf/
│   └── layer.conf                      # Layer registration and metadata
│
├── classes/
│   └── medtech-image.bbclass           # Shared image policy (no debug pkgs, etc.)
│
├── recipes-core/
│   └── medtech-system/
│       └── medtech-system.bb           # Base OS configuration and release files
│
├── recipes-image/
│   └── core-image-medtech/
│       └── core-image-medtech.bb       # Final image definition
│
├── recipes-qt/
│   └── (Qt6 configuration appends)
│
├── recipes-services/
│   ├── medtech-vitals-publisher/
│   │   └── medtech-vitals-publisher_1.0.bb
│   ├── medtech-edge-analytics/
│   │   └── medtech-edge-analytics_1.0.bb
│   └── medtech-clinician-ui/
│       └── medtech-clinician-ui_1.0.bb
│
└── recipes-support/
    ├── mosquitto/
    │   └── mosquitto_%.bbappend        # Mosquitto configuration append
    ├── python3-paho-mqtt/
    │   └── python3-paho-mqtt_1.6.1.bb  # Python MQTT client library
    └── tensorflow-lite/
        └── tensorflow-lite_2.14.0.bb   # TFLite for sepsis detection
```

---

## Layer Configuration

The `conf/layer.conf` file registers the layer with BitBake. Key settings:

| Setting | Value | Purpose |
|---|---|---|
| `BBFILE_PRIORITY` | 6 | Higher than OE layers (5); our appends win |
| `LAYERDEPENDS` | core, openembedded-layer, networking-layer, qt6-layer | Required layers |
| `LAYERSERIES_COMPAT` | kirkstone langdale scarthgap | Yocto versions supported |

See the file itself (`yocto/meta-medtech/conf/layer.conf`) for detailed comments
on each setting.

---

## Recipe Categories

### `recipes-core/`
Base system configuration. `medtech-system.bb` installs `/etc/medtech-release`
with build version and timestamp, and any core OS tweaks.

### `recipes-image/`
Image definition. `core-image-medtech.bb` specifies `IMAGE_INSTALL` (the full
package list) and inherits from `medtech-image.bbclass` for shared policies.

### `recipes-services/`
The medtech application services. Each service has:
- A Python or compiled source tarball (or inline files)
- A systemd service file
- Proper `RDEPENDS` on runtime libraries

### `recipes-support/`
Third-party packages not available upstream or requiring customization:
- `mosquitto_%.bbappend` — enables specific Mosquitto build features
- `python3-paho-mqtt_1.6.1.bb` — MQTT client for vitals publisher
- `tensorflow-lite_2.14.0.bb` — TFLite for edge analytics

### `classes/`
`medtech-image.bbclass` provides shared image policies applied to all medtech
images, such as disabling debug packages and setting default features.

---

## Recipe Naming Conventions

```
<package-name>_<version>.bb
```

Examples:
- `medtech-vitals-publisher_1.0.bb` — version 1.0 of the vitals publisher
- `python3-paho-mqtt_1.6.1.bb` — Python paho-mqtt version 1.6.1
- `tensorflow-lite_2.14.0.bb` — TFLite version 2.14.0

**Appends** use `%` as a wildcard for the version:
- `mosquitto_%.bbappend` — applies to any version of mosquitto

---

## Adding a New Service Recipe

This example adds a hypothetical `medtech-alarm-manager` service.

### Step 1: Create the recipe directory

```bash
mkdir -p yocto/meta-medtech/recipes-services/medtech-alarm-manager
```

### Step 2: Create the recipe file

```bash
cat > yocto/meta-medtech/recipes-services/medtech-alarm-manager/medtech-alarm-manager_1.0.bb
```

```bitbake
DESCRIPTION = "MedTech alarm manager — monitors vitals thresholds and triggers alerts"
LICENSE = "CLOSED"
LIC_FILES_CHKSUM = ""

# Source: local files in this recipe directory
SRC_URI = "file://alarm-manager.py \
           file://medtech-alarm-manager.service \
          "

# Runtime dependencies
RDEPENDS:${PN} = "python3 python3-paho-mqtt"

# Install the service
do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/alarm-manager.py ${D}${bindir}/alarm-manager

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/medtech-alarm-manager.service \
        ${D}${systemd_system_unitdir}/medtech-alarm-manager.service
}

# Enable the systemd service on boot
inherit systemd
SYSTEMD_SERVICE:${PN} = "medtech-alarm-manager.service"
SYSTEMD_AUTO_ENABLE = "enable"
```

### Step 3: Add source files

```
yocto/meta-medtech/recipes-services/medtech-alarm-manager/
├── medtech-alarm-manager_1.0.bb
├── alarm-manager.py
└── medtech-alarm-manager.service
```

### Step 4: Add to the image

Edit `yocto/meta-medtech/recipes-image/core-image-medtech/core-image-medtech.bb`:

```bitbake
IMAGE_INSTALL:append = " medtech-alarm-manager"
```

### Step 5: Build and test

```bash
# Build only this recipe first
bitbake medtech-alarm-manager

# Then rebuild the full image
bitbake core-image-medtech
```

---

## Systemd Service File Pattern

All medtech services use systemd. Follow this pattern for consistency:

```ini
[Unit]
Description=MedTech Alarm Manager
After=medtech-vitals-publisher.service
Requires=mosquitto.service

[Service]
Type=simple
ExecStart=/usr/bin/alarm-manager
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Key points:
- Use `After=` for ordering (not strict dependency)
- Use `Requires=` only for hard dependencies (the service won't start if the dependency fails)
- Use `Restart=on-failure` for resilience
- Log to journal with `StandardOutput=journal`

---

## Versioning Strategy

Recipe versions follow semantic versioning (`MAJOR.MINOR`):

| Version | When to bump |
|---|---|
| `1.0` | Initial release |
| `1.1` | Bug fixes, minor feature additions |
| `2.0` | Breaking API changes or major rewrites |

When bumping a version, rename the `.bb` file:
```bash
mv medtech-vitals-publisher_1.0.bb medtech-vitals-publisher_1.1.bb
```

BitBake will automatically use the latest version by default. To pin to a specific
version in the image:
```bitbake
PREFERRED_VERSION_medtech-vitals-publisher = "1.0"
```

---

## Layer Dependencies

Why each dependency is needed:

| Layer | Required for |
|---|---|
| `core` (Poky/OE-Core) | Base Linux, kernel, busybox, systemd, Python3 |
| `openembedded-layer` (meta-oe) | mosquitto, additional Python packages |
| `networking-layer` (meta-networking) | Network tools, socket libraries |
| `qt6-layer` (meta-qt6) | Qt6 framework for medtech-clinician-ui |

These are declared in `LAYERDEPENDS_meta-medtech` in `conf/layer.conf`.
