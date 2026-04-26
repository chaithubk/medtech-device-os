DESCRIPTION = "MedTech System Base - installs layout, users and base dependencies"
SUMMARY = "MedTech system base package"
LICENSE = "CLOSED"
PV = "1.0"

inherit systemd

# Runtime dependencies shared by all medtech services
RDEPENDS:${PN} = " \
    python3 \
    python3-core \
    python3-json \
    python3-logging \
    python3-threading \
    mosquitto \
"

S = "${WORKDIR}"

do_install() {
    # Create medtech directory layout
    install -d ${D}/opt/medtech
    install -d ${D}/opt/medtech/models
    install -d ${D}/var/log/medtech
    install -d ${D}/etc/medtech
}

FILES:${PN} = " \
    /opt/medtech \
    /var/log/medtech \
    /etc/medtech \
"
