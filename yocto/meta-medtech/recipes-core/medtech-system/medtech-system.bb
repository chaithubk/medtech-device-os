DESCRIPTION = "MedTech System Base - installs layout, users and base dependencies"
SUMMARY = "MedTech system base package"
LICENSE = "CLOSED"
PV = "1.0"

inherit systemd

SRCREV = "c337d89452b23b3cb7460941364fc1b2255837c9" # medtech-telemetry-contract v2.0.0 tag
SRC_URI = " \
    git://github.com/chaithubk/medtech-telemetry-contract.git;protocol=https;branch=main \
    file://medtech-system.conf \
    file://medtech-contract-info \
"
VITALS_CONTRACT_VERSION = "v2.0"
VITALS_SCHEMA_FILE = "${VITALS_CONTRACT_VERSION}.json"

# Runtime dependencies shared by all medtech services
RDEPENDS:${PN} = " \
    python3 \
    mosquitto \
"

S = "${WORKDIR}/git"

do_install() {
    # Create medtech directory layout
    install -d ${D}/opt/medtech
    install -d ${D}/opt/medtech/models
    install -d ${D}/etc/medtech
    install -d ${D}${datadir}/medtech/contracts/vitals
    install -d ${D}${bindir}

    # Install pinned telemetry contract schema and canonical link
    install -m 0644 ${S}/schemas/vitals/${VITALS_SCHEMA_FILE} ${D}${datadir}/medtech/contracts/vitals/${VITALS_SCHEMA_FILE}
    ln -sf ${VITALS_SCHEMA_FILE} ${D}${datadir}/medtech/contracts/vitals/current.json
    install -m 0644 /dev/null ${D}${datadir}/medtech/contracts/VITALS_CONTRACT_VERSION
    printf "%s\n" "${VITALS_CONTRACT_VERSION}" > ${D}${datadir}/medtech/contracts/VITALS_CONTRACT_VERSION

    # Install tmpfiles.d config to create /var/log/medtech at boot
    # (do NOT pre-create /var/volatile dirs — they must be empty in the image)
    install -d ${D}${sysconfdir}/tmpfiles.d
    install -m 0644 ${WORKDIR}/medtech-system.conf ${D}${sysconfdir}/tmpfiles.d/medtech-system.conf
    install -m 0755 ${WORKDIR}/medtech-contract-info ${D}${bindir}/medtech-contract-info
}

FILES:${PN} = " \
    /opt/medtech \
    /etc/medtech \
    ${datadir}/medtech/contracts \
    ${bindir}/medtech-contract-info \
    ${sysconfdir}/tmpfiles.d/medtech-system.conf \
"
