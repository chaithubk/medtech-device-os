# medtech-image.bbclass
# Minimal runtime image composition and post-processing for constrained CI builds.

inherit core-image

# Core runtime (small, production-relevant baseline only)
MEDTECH_CORE_PKGS = " \
    systemd \
    systemd-analyze \
    openssh \
    openssh-sftp-server \
    curl \
"

# Python runtime for services
MEDTECH_PYTHON_PKGS = " \
    python3 \
    python3-numpy \
"

# MQTT stack
MEDTECH_MQTT_PKGS = " \
    mosquitto \
    mosquitto-clients \
    python3-paho-mqtt \
"

# Qt6 stack for clinician UI (offscreen/headless-friendly)
MEDTECH_QT6_PKGS = " \
    qtbase \
    qtdeclarative \
    qtmqtt \
    fontconfig \
    freetype \
"

# MedTech services
MEDTECH_SERVICES = " \
    medtech-system \
    medtech-vitals-publisher \
    medtech-clinician-ui \
"

IMAGE_INSTALL:append = " \
    ${MEDTECH_CORE_PKGS} \
    ${MEDTECH_PYTHON_PKGS} \
    ${MEDTECH_MQTT_PKGS} \
    ${MEDTECH_QT6_PKGS} \
    ${MEDTECH_SERVICES} \
"

IMAGE_FEATURES = "ssh-server-openssh"
IMAGE_FEATURES:remove = "debug-tweaks dbg-pkgs dev-pkgs tools-debug tools-profile tools-sdk"
PACKAGE_EXCLUDE_COMPLEMENTARY = ".*-dbg|.*-dev|.*-staticdev"

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


