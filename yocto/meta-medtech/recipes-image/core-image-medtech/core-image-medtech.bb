DESCRIPTION = "MedTech Medical IoT Image - Stage 1"
SUMMARY = "Complete MedTech image with MQTT broker, vitals publisher, edge analytics and clinician UI"
LICENSE = "CLOSED"

inherit core-image medtech-image

# Base packages
IMAGE_INSTALL:append = " \
    python3 \
    python3-pip \
    python3-core \
    python3-logging \
    python3-json \
    python3-threading \
    python3-numpy \
    openssh \
    openssh-ssh \
    curl \
    wget \
    nano \
    htop \
    systemd \
    systemd-analyze \
    rsyslog \
"

# MQTT broker
IMAGE_INSTALL:append = " \
    mosquitto \
    mosquitto-clients \
"

# Python MQTT library
IMAGE_INSTALL:append = " \
    python3-paho-mqtt \
"

# TensorFlow Lite runtime
IMAGE_INSTALL:append = " \
    tensorflow-lite \
"

# Qt6 support for clinician-ui (OpenGL/offscreen backend — no Vulkan/Wayland)
IMAGE_INSTALL:append = " \
    qtbase \
    qtdeclarative \
    qtmqtt \
    mesa \
    fontconfig \
    freetype \
"

# MedTech services (order reflects systemd dependencies)
IMAGE_INSTALL:append = " \
    medtech-system \
    vitals-publisher \
    edge-analytics \
    clinician-ui \
"

# SSH server and debug tweaks (debug-tweaks allows passwordless root login -
# REMOVE for production hardening before hardware deployment)
IMAGE_FEATURES += "ssh-server-openssh debug-tweaks"

# Image size settings
IMAGE_ROOTFS_SIZE = "524288"
IMAGE_OVERHEAD_FACTOR = "1.5"
