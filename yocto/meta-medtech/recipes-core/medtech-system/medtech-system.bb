DESCRIPTION = "MedTech System Base - installs layout, users and base dependencies"
SUMMARY = "MedTech system base package"
LICENSE = "CLOSED"
PV = "1.0"

inherit systemd

SRC_URI += "file://medtech-system.conf"

# Runtime dependencies shared by all medtech services
RDEPENDS:${PN} = " \
    python3 \
    mosquitto \
"

S = "${WORKDIR}"

do_install() {
    # Create medtech directory layout
    install -d ${D}/opt/medtech
    install -d ${D}/opt/medtech/models
    install -d ${D}/etc/medtech

    # Install tmpfiles.d config to create /var/log/medtech at boot
    # (do NOT pre-create /var/volatile dirs — they must be empty in the image)
    install -d ${D}${sysconfdir}/tmpfiles.d
    install -m 0644 ${WORKDIR}/medtech-system.conf ${D}${sysconfdir}/tmpfiles.d/medtech-system.conf
}

FILES:${PN} = " \
    /opt/medtech \
    /etc/medtech \
    ${sysconfdir}/tmpfiles.d/medtech-system.conf \
"
