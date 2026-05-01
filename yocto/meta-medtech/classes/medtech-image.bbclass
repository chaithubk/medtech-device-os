# medtech-image.bbclass
# Minimal runtime image composition and post-processing for constrained CI builds.

inherit core-image extrausers

# Keep baseline lean: avoid pulling packagegroup-base-extended and feature-driven extras.
CORE_IMAGE_BASE_INSTALL = "packagegroup-core-boot"

# Drop optional platform features not needed by the current service set.
# This helps reduce transitive dependencies and build time.
# - alsa/usb/pcmcia/nfs are pulled by poky default DISTRO and drag in audio/storage stacks
#   that this medical-IoT image does not use.
DISTRO_FEATURES:remove = "ptest pulseaudio bluetooth wifi nfc 3g zeroconf \
                          gobject-introspection-data alsa pcmcia usbgadget usbhost \
                          nfs irda x11 wayland vulkan polkit"

# Disable docs/introspection generators globally — heavy native builds we don't ship.
GI_DATA_ENABLED = "False"
GTKDOC_ENABLED = "False"
ENABLE_BINARY_LOCALE_GENERATION = "0"

# Core runtime (small, production-relevant baseline only)
# Removed: systemd-analyze (diagnostic only), openssh-sftp-server (SFTP not used)
MEDTECH_CORE_PKGS = " \
    systemd \
    openssh \
    curl \
"

# Python runtime for services
MEDTECH_PYTHON_PKGS = " \
    python3 \
"

# MQTT stack
# mosquitto-clients (mosquitto_pub/sub) is debug-only — services use libmosquitto/paho directly.
MEDTECH_MQTT_PKGS = " \
    mosquitto \
    python3-paho-mqtt \
"

# Qt6 stack for clinician UI (offscreen/headless-friendly)
MEDTECH_QT6_PKGS = " \
    qtbase \
    qtdeclarative \
    qtmqtt \
    qtsvg \
    fontconfig \
    freetype \
"

# ML runtime only
MEDTECH_ML_PKGS = " \
    tensorflow-lite \
"

# MedTech services
MEDTECH_SERVICES = " \
    medtech-system \
    medtech-vitals-publisher \
    medtech-edge-analytics \
    medtech-clinician-ui \
"

IMAGE_INSTALL:append = " \
    ${MEDTECH_CORE_PKGS} \
    ${MEDTECH_PYTHON_PKGS} \
    ${MEDTECH_MQTT_PKGS} \
    ${MEDTECH_QT6_PKGS} \
    ${MEDTECH_SERVICES} \
    ${MEDTECH_ML_PKGS} \
"

IMAGE_FEATURES = "ssh-server-openssh"
IMAGE_FEATURES:remove = "debug-tweaks dbg-pkgs dev-pkgs tools-debug tools-profile tools-sdk"
PACKAGE_EXCLUDE_COMPLEMENTARY = ".*-dbg|.*-dev|.*-staticdev"

# ---------------------------------------------------------------------------
# Bloat suppression — block transitive RRECOMMENDS that creep in from
# packagegroup-base / systemd / udev defaults but are not used by this image.
# These are dropped at do_rootfs time, after audit-image-deps.sh confirmed they
# are pure transitive (not in any service's hard RDEPENDS).
# ---------------------------------------------------------------------------
BAD_RECOMMENDATIONS:append = " \
    bash-completion \
    bluez5 \
    btrfs-tools \
    eudev-hwdb \
    git \
    gnutls \
    kbd \
    kbd-consolefonts \
    kbd-keymaps \
    libical \
    libmicrohttpd \
    mdadm \
    nfs-utils-client \
    perl \
    ptest-runner \
    python3-pygobject \
    python3-dbus \
    rsync \
    socat \
    strace \
    systemd-analyze \
    systemd-bash-completion \
    vala \
    wpa-supplicant \
"

# Belt-and-braces — even if some upstream recipe makes a hard RDEPENDS on these
# we will not silently install them; the build will fail loudly so we can
# evaluate. Comment out a line if a build genuinely needs the package.
PACKAGE_EXCLUDE += "\
    bluez5 \
    libical \
    libmicrohttpd \
    gnome-desktop-testing \
    python3-pygobject \
    python3-dbus \
    qtwayland \
    qtwebengine \
    qtmultimedia \
    qttools \
    qtlanguageserver \
"

# Tighten kernel module recommendations — only ship what hardware needs.
# qemuarm64 + ext4 + virtio is enough for the CI image.
KERNEL_MODULE_AUTOLOAD = ""

# QEMU/dev convenience: set a deterministic root password for console and SSH login.
# NOTE: change this for production images.
# Password is: root
EXTRA_USERS_PARAMS = "usermod -p '\$6\$medtech\$740u6fNedx0nA9SngnkoyPLK4CzMswgec09ev5wJsPFH4GEOW4QN3oyLdS8f6wphE7Ub7i9.oqjez8ss75nue/' root;"

IMAGE_ROOTFS_SIZE = "524288"
IMAGE_OVERHEAD_FACTOR = "1.5"

# Guard against accidentally pulling in old Qt5 packages.
IMAGE_INSTALL:remove = "qt5"

# Keep workdir cleanup and SPDX enabled even if local.conf is overridden.
INHERIT += "rm_work create-spdx"
RM_WORK_EXCLUDE += "core-image-medtech"
SPDX_PRETTY = "1"
SPDX_ARCHIVE_COMPRESS = "gz"
SPDX_INCLUDE_SOURCES = "0"

MEDTECH_IMAGE_VERSION ?= "1.0.0"
MEDTECH_IMAGE_NAME ?= "core-image-medtech"

# Stamp release info into the rootfs
IMAGE_PREPROCESS_COMMAND:append = " medtech_stamp_release; "

medtech_stamp_release() {
    install -d ${IMAGE_ROOTFS}/etc
    cat > ${IMAGE_ROOTFS}/etc/medtech-release << EOF
MEDTECH_IMAGE_NAME="${MEDTECH_IMAGE_NAME}"
MEDTECH_IMAGE_VERSION="${MEDTECH_IMAGE_VERSION}"
MEDTECH_BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
MEDTECH_MACHINE="${MACHINE}"
MEDTECH_DISTRO="${DISTRO}"
EOF
}


