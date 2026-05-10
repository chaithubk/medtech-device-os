SUMMARY = "First-boot SSH public key provisioning for MedTech images"
DESCRIPTION = "Interactive first-boot setup script that prompts user to provision their SSH public key via serial console."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://firstboot-ssh-setup.sh \
    file://firstboot-ssh-setup.service \
"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/firstboot-ssh-setup.sh ${D}${bindir}/firstboot-ssh-setup

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/firstboot-ssh-setup.service ${D}${systemd_system_unitdir}/
}

inherit systemd

SYSTEMD_AUTO_ENABLE = "enable"
SYSTEMD_SERVICE:${PN} = "firstboot-ssh-setup.service"

RDEPENDS:${PN} = "systemd bash"
