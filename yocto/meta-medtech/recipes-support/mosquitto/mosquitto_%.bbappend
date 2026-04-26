# MedTech MQTT broker configuration overlay
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://medtech-mosquitto.conf \
"

inherit systemd

SYSTEMD_SERVICE:${PN} = "mosquitto.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install:append() {
    install -D -m 0644 ${WORKDIR}/medtech-mosquitto.conf ${D}${sysconfdir}/mosquitto/conf.d/medtech.conf
    # Ensure persistence directory exists
    install -d ${D}${localstatedir}/lib/mosquitto
}

FILES:${PN} += "${localstatedir}/lib/mosquitto"
