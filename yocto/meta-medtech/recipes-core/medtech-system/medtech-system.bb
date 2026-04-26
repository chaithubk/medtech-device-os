DESCRIPTION = "MedTech System Base - installs layout, users and base dependencies"
SUMMARY = "MedTech system base package"
LICENSE = "CLOSED"
PV = "1.0"

inherit systemd

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
    # On Yocto, /var/log is commonly a symlink to /var/volatile/log.
    # Package the real path to avoid do_package symlink parent errors.
    install -d ${D}${localstatedir}/volatile/log/medtech
    install -d ${D}/etc/medtech
}

FILES:${PN} = " \
    /opt/medtech \
    ${localstatedir}/volatile/log/medtech \
    /etc/medtech \
"
