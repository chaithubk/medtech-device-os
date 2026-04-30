DESCRIPTION = "MedTech Edge Analytics - Sepsis detection service"
LICENSE = "CLOSED"
PV = "1.0"

inherit systemd

SRCREV = "093564ae8651359c60b66491351c13f2d8819ef0"
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
    if [ -n "${@bb.utils.contains('MACHINE', 'qemuarm64', 'yes', '', d)}" ]; then
        if [ ! -f ${S}/models/sepsis_model_qemu.tflite ]; then
            echo "ERROR: sepsis_model_qemu.tflite not found in source repo at ${S}/models/sepsis_model_qemu.tflite" >&2
            exit 1
        fi
        install -m 0644 ${S}/models/sepsis_model_qemu.tflite ${D}/opt/medtech/models/
    else
        if [ ! -f ${S}/models/sepsis_model.tflite ]; then
            echo "ERROR: sepsis_model.tflite not found in source repo at ${S}/models/sepsis_model.tflite" >&2
            exit 1
        fi
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
