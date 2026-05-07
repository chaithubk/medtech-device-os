DESCRIPTION = "MedTech System Base - installs layout, users and base dependencies"
SUMMARY = "MedTech system base package"
LICENSE = "CLOSED"
PV = "1.0"

inherit systemd

SRC_URI += " \
    file://medtech-system.conf \
    git://github.com/chaithubk/medtech-telemetry-contract.git;protocol=https;branch=main;destsuffix=telemetry-contract \
"
SRCREV = "c337d89452b23b3cb7460941364fc1b2255837c9"

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

    # Install centralized vitals telemetry contract files
    install -d ${D}${datadir}/medtech/contracts/vitals
    install -m 0644 ${WORKDIR}/telemetry-contract/schemas/vitals/v2.0.json \
        ${D}${datadir}/medtech/contracts/vitals/v2.0.json
    ln -sf v2.0.json ${D}${datadir}/medtech/contracts/vitals/current.json
    printf "v2.0.0\n" > ${D}${datadir}/medtech/contracts/VITALS_CONTRACT_VERSION
}

FILES:${PN} = " \
    /opt/medtech \
    /etc/medtech \
    ${datadir}/medtech/contracts \
    ${sysconfdir}/tmpfiles.d/medtech-system.conf \
"
