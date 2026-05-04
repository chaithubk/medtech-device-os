# Recipes Guide

Conventions, patterns, and examples for writing Yocto recipes in meta-medtech.

---

## Table of Contents

- [Recipe Basics](#recipe-basics)
- [File Layout](#file-layout)
- [Common Recipe Variables](#common-recipe-variables)
- [Recipe Examples](#recipe-examples)
  - [Python Service Recipe](#python-service-recipe)
  - [Compiled Binary Recipe](#compiled-binary-recipe)
  - [bbappend Example](#bbappend-example)
- [Systemd Integration](#systemd-integration)
- [Adding Runtime Dependencies](#adding-runtime-dependencies)
- [License Declarations](#license-declarations)
- [Testing Recipes](#testing-recipes)

---

## Recipe Basics

A Yocto recipe (`.bb` file) describes how to:
1. Fetch source code (`SRC_URI`)
2. Configure/compile it
3. Install files into the image staging area
4. Declare runtime dependencies

BitBake reads recipes and produces packages that are assembled into the final
rootfs image.

---

## File Layout

```
recipes-services/<name>/
├── <name>_<version>.bb      # Recipe file
├── <source-file>.py         # Source files (for local SRC_URI)
├── <name>.service           # Systemd service file
└── <config-file>.conf       # Optional config files
```

---

## Common Recipe Variables

| Variable | Purpose | Example |
|---|---|---|
| `DESCRIPTION` | One-line description | `"MedTech vitals publisher"` |
| `LICENSE` | SPDX license identifier | `"MIT"` or `"CLOSED"` |
| `LIC_FILES_CHKSUM` | License file checksum | `"file://LICENSE;md5=abc123"` |
| `SRC_URI` | Source files | `"file://vitals-publisher.py"` |
| `RDEPENDS:${PN}` | Runtime dependencies | `"python3 python3-paho-mqtt"` |
| `DEPENDS` | Build-time dependencies | `"cmake"` |
| `FILES:${PN}` | Files to include in package | `"${bindir}/* ${systemd_system_unitdir}/*"` |
| `SYSTEMD_SERVICE:${PN}` | Systemd service file name | `"medtech-vitals-publisher.service"` |

---

## Recipe Examples

### Python Service Recipe

```bitbake
# medtech-vitals-publisher_1.0.bb
DESCRIPTION = "MedTech vitals publisher — simulates patient vitals via MQTT"
LICENSE = "CLOSED"
LIC_FILES_CHKSUM = ""

# Source files are bundled with this recipe in the same directory
SRC_URI = "file://vitals-publisher.py \
           file://medtech-vitals-publisher.service \
          "

# Runtime dependencies — must be available in the final image
RDEPENDS:${PN} = "python3 python3-paho-mqtt"

do_install() {
    # Install the Python script as an executable
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/vitals-publisher.py ${D}${bindir}/vitals-publisher

    # Install the systemd service file
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/medtech-vitals-publisher.service \
        ${D}${systemd_system_unitdir}/medtech-vitals-publisher.service
}

# Enable the service at boot
inherit systemd
SYSTEMD_SERVICE:${PN} = "medtech-vitals-publisher.service"
SYSTEMD_AUTO_ENABLE = "enable"
```

### Compiled Binary Recipe

```bitbake
# medtech-analytics-engine_1.0.bb
DESCRIPTION = "MedTech analytics engine — compiled C++ binary"
LICENSE = "CLOSED"
LIC_FILES_CHKSUM = ""

SRC_URI = "file://analytics-engine.tar.gz \
           file://medtech-analytics-engine.service \
          "
SRC_URI[md5sum] = "abc123..."
SRC_URI[sha256sum] = "def456..."

# Build-time dependencies
DEPENDS = "tensorflow-lite"

# Runtime dependencies (shared libraries)
RDEPENDS:${PN} = "tensorflow-lite"

# Use cmake to build
inherit cmake

do_install:append() {
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/medtech-analytics-engine.service \
        ${D}${systemd_system_unitdir}/medtech-analytics-engine.service
}

inherit systemd
SYSTEMD_SERVICE:${PN} = "medtech-analytics-engine.service"
SYSTEMD_AUTO_ENABLE = "enable"
```

### bbappend Example

Use `.bbappend` to customize an upstream recipe without forking it:

```bitbake
# mosquitto_%.bbappend
# Applies to any version of mosquitto from meta-openembedded

# Enable WebSocket support (disabled by default)
EXTRA_OECONF:append = " --with-websockets"

# Disable TLS (our internal MQTT is local-only)
EXTRA_OECONF:append = " --without-tls"

# Install our custom configuration file
SRC_URI:append = " file://mosquitto.conf"

do_install:append() {
    install -m 0644 ${WORKDIR}/mosquitto.conf ${D}${sysconfdir}/mosquitto/mosquitto.conf
}
```

---

## Systemd Integration

All medtech services use the `systemd` bbclass for clean integration:

```bitbake
inherit systemd

# Name of the service file (must match the installed filename)
SYSTEMD_SERVICE:${PN} = "my-service.service"

# Enable at boot (default: enable)
# Use "disable" for services that should be started manually
SYSTEMD_AUTO_ENABLE = "enable"
```

The `do_install` function must install the service file to:
```
${D}${systemd_system_unitdir}/my-service.service
```

Which expands to `/lib/systemd/system/my-service.service` in the image.

### Service file template

```ini
[Unit]
Description=MedTech My Service
Documentation=https://github.com/chaithubk/medtech-device-os
After=network.target mosquitto.service
Wants=mosquitto.service

[Service]
Type=simple
ExecStart=/usr/bin/my-service
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal
SyslogIdentifier=my-service

[Install]
WantedBy=multi-user.target
```

---

## Adding Runtime Dependencies

### Python packages

Add to `RDEPENDS:${PN}`:
```bitbake
RDEPENDS:${PN} = "python3 python3-paho-mqtt python3-json"
```

Find available Python packages:
```bash
# In the container
bitbake -s | grep python3-
```

### Shared libraries

For compiled code, use `RDEPENDS` for packages or `DEPENDS` for build-time:
```bitbake
DEPENDS = "openssl zlib"                    # build-time
RDEPENDS:${PN} = "libssl libz python3"      # runtime
```

### Adding a new Python package recipe

If the package isn't available upstream, create it in `recipes-support/`:

```bitbake
# python3-my-package_1.2.3.bb
DESCRIPTION = "Python my-package library"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=..."

SRC_URI = "https://pypi.io/packages/source/m/my-package/my-package-${PV}.tar.gz"
SRC_URI[sha256sum] = "..."

inherit setuptools3
```

---

## License Declarations

| License | `LICENSE` value | Notes |
|---|---|---|
| Proprietary/internal | `"CLOSED"` | No `LIC_FILES_CHKSUM` needed |
| MIT | `"MIT"` | Requires `LIC_FILES_CHKSUM` |
| Apache 2.0 | `"Apache-2.0"` | Requires `LIC_FILES_CHKSUM` |
| GPL 2.0 | `"GPL-2.0-only"` | Careful with image licensing |

For internal code, use `CLOSED`:
```bitbake
LICENSE = "CLOSED"
LIC_FILES_CHKSUM = ""
```

---

## Testing Recipes

### Build and inspect a single recipe

```bash
# Build only this recipe (much faster than full image)
bitbake medtech-vitals-publisher

# Check installed files
find yocto/build/tmp/work/*/medtech-vitals-publisher/*/image/ -type f

# Show all recipe variables
bitbake -e medtech-vitals-publisher

# List available tasks
bitbake -c listtasks medtech-vitals-publisher
```

### Rebuild after changes

```bash
# Clean the recipe work directory
bitbake -c cleansstate medtech-vitals-publisher

# Rebuild
bitbake medtech-vitals-publisher
```

### Test in a full image

After recipe changes, rebuild the full image:
```bash
bitbake core-image-medtech
bash scripts/run-qemu.sh
# Inside VM:
systemctl status medtech-vitals-publisher
journalctl -u medtech-vitals-publisher -f
```
