DESCRIPTION = "MedTech Vitals Publisher - MQTT vital signs publisher"
SUMMARY = "Publishes patient vital signs over MQTT"
HOMEPAGE = "https://github.com/chaithubk/medtech-vitals-publisher"
LICENSE = "CLOSED"
PV = "1.0"

inherit systemd

SRCREV = "e03e4be5414cf9c260dd9067fc6971dcb6f7cbee"
SRC_URI = " \
    git://github.com/chaithubk/medtech-vitals-publisher.git;protocol=https;branch=main \
    file://vitals-publisher.service \
    file://vitals-publisher.env \
"

S = "${WORKDIR}/git"

RDEPENDS:${PN} = " \
    python3 \
    python3-paho-mqtt \
    medtech-system \
"

SYSTEMD_SERVICE:${PN} = "medtech-vitals-publisher.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    # Install application, excluding VCS metadata and non-runtime artifacts
    install -d ${D}/opt/medtech/vitals-publisher
    (
        cd ${S}
        tar --exclude-vcs \
            --exclude='__pycache__' \
            --exclude='*.pyc' \
            --exclude='.pytest_cache' \
            -cf - .
    ) | (
        cd ${D}/opt/medtech/vitals-publisher
        tar --no-same-owner -xf -
    )

    # Make all Python files executable (entry points and helpers)
    find ${D}/opt/medtech/vitals-publisher -name "*.py" -exec chmod 0755 {} \;

    # Install environment configuration
    install -d ${D}${sysconfdir}/medtech
    install -m 0644 ${WORKDIR}/vitals-publisher.env ${D}${sysconfdir}/medtech/vitals-publisher.env

    # Install systemd service
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/vitals-publisher.service ${D}${systemd_system_unitdir}/medtech-vitals-publisher.service

}

FILES:${PN} = " \
    /opt/medtech/vitals-publisher \
    ${sysconfdir}/medtech/vitals-publisher.env \
    ${systemd_system_unitdir}/medtech-vitals-publisher.service \
"
