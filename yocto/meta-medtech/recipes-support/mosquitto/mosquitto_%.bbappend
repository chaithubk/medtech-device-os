# MedTech MQTT broker configuration overlay
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://medtech-mosquitto.conf"

do_install:append() {
    install -D -m 0644 ${WORKDIR}/medtech-mosquitto.conf ${D}${sysconfdir}/mosquitto/conf.d/medtech.conf
}
