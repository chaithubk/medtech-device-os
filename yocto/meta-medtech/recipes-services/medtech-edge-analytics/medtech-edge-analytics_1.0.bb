DESCRIPTION = "MedTech Edge Analytics - Sepsis detection with TensorFlow Lite"
SUMMARY = "MQTT-driven ML inference service for sepsis detection"
HOMEPAGE = "https://github.com/chaithubk/medtech-edge-analytics"
LICENSE = "CLOSED"
PV = "1.0"

inherit systemd

SRCREV = "2ff320cc820db7692a2847db9c4ead5ccb7f8cfe"
SRC_URI = " \
    git://github.com/chaithubk/medtech-edge-analytics.git;protocol=https;branch=main \
    file://edge-analytics.service \
    file://edge-analytics.env \
"

S = "${WORKDIR}/git"

RDEPENDS:${PN} = " \
    python3 \
    python3-numpy \
    python3-paho-mqtt \
    tensorflow-lite \
    medtech-system \
"

SYSTEMD_SERVICE:${PN} = "medtech-edge-analytics.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    # Install application, excluding VCS metadata and non-runtime artifacts
    install -d ${D}/opt/medtech/edge-analytics
    (
        cd ${S}
        tar --exclude-vcs \
            --exclude='__pycache__' \
            --exclude='*.pyc' \
            --exclude='.pytest_cache' \
            -cf - .
    ) | (
        cd ${D}/opt/medtech/edge-analytics
        tar -xf -
    )

    # Make all Python files executable (entry points and helpers)
    find ${D}/opt/medtech/edge-analytics -name "*.py" -exec chmod 0755 {} \;

    # Install TFLite model if present
    install -d ${D}/opt/medtech/models
    if [ -f ${S}/models/sepsis_model.tflite ]; then
        install -m 0644 ${S}/models/sepsis_model.tflite ${D}/opt/medtech/models/sepsis_model.tflite
    fi

    # Install environment configuration
    install -d ${D}${sysconfdir}/medtech
    install -m 0644 ${WORKDIR}/edge-analytics.env ${D}${sysconfdir}/medtech/edge-analytics.env

    # Install systemd service
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/edge-analytics.service ${D}${systemd_system_unitdir}/medtech-edge-analytics.service

}

FILES:${PN} = " \
    /opt/medtech/edge-analytics \
    /opt/medtech/models \
    ${sysconfdir}/medtech/edge-analytics.env \
    ${systemd_system_unitdir}/medtech-edge-analytics.service \
"
