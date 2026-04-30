DESCRIPTION = "MedTech Edge Analytics - Sepsis detection service"
LICENSE = "CLOSED"
PV = "1.0"

inherit systemd

SRCREV = "2ff320cc820db7692a2847db9c4ead5ccb7f8cfe"
SRC_URI = " \
    git://github.com/chaithubk/medtech-edge-analytics.git;protocol=https;branch=main \
    file://medtech-edge-analytics.service \
    file://edge-analytics.env \
"

S = "${WORKDIR}/git"

# Now satisfied by the RPROVIDES in the tensorflow-lite recipe
RDEPENDS:${PN} = " \
    python3-core \
    python3-numpy \
    python3-paho-mqtt \
    python3-tensorflow-lite \
    medtech-system \
"

SYSTEMD_SERVICE:${PN} = "medtech-edge-analytics.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    # Install Python Application
    install -d ${D}/opt/medtech/edge-analytics
    cp -r ${S}/* ${D}/opt/medtech/edge-analytics/
    rm -rf ${D}/opt/medtech/edge-analytics/.git
    find ${D}/opt/medtech/edge-analytics -name "*.py" -exec chmod 0755 {} \;

    # Install Model (Matches MODEL_PATH in .env)
    install -d ${D}/opt/medtech/models
    if [ -f ${S}/models/sepsis_model.tflite ]; then
        install -m 0644 ${S}/models/sepsis_model.tflite ${D}/opt/medtech/models/
    fi

    # Install Configuration and Systemd Unit
    install -d ${D}${sysconfdir}/medtech
    install -m 0644 ${WORKDIR}/edge-analytics.env ${D}${sysconfdir}/medtech/edge-analytics.env
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/medtech-edge-analytics.service ${D}${systemd_system_unitdir}/medtech-edge-analytics.service
}

FILES:${PN} = " \
    /opt/medtech/edge-analytics \
    /opt/medtech/models \
    ${sysconfdir}/medtech/edge-analytics.env \
    ${systemd_system_unitdir}/medtech-edge-analytics.service \
"
