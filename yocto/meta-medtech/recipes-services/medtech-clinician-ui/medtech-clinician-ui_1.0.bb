DESCRIPTION = "MedTech Clinician UI - Qt6-based clinical dashboard"
SUMMARY = "Qt6 GUI application for displaying patient vitals and ML predictions"
HOMEPAGE = "https://github.com/chaithubk/medtech-clinician-ui"
LICENSE = "CLOSED"
PV = "1.0"

inherit qt6-cmake systemd

SRCREV = "6e24f83e0bb8c082906b2730e2a2267e091592d0"
SRC_URI = " \
    git://github.com/chaithubk/medtech-clinician-ui.git;protocol=https;branch=main \
    file://clinician-ui.service \
    file://clinician-ui.env \
    file://qt-config.conf \
"

S = "${WORKDIR}/git"

DEPENDS = " \
    qtbase \
    qtbase-native \
    qtdeclarative \
    qtmqtt \
"

RDEPENDS:${PN} = " \
    qtbase \
    qtdeclarative \
    fontconfig \
    freetype \
    medtech-edge-analytics \
    medtech-system \
"

SYSTEMD_SERVICE:${PN} = "medtech-clinician-ui.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

EXTRA_OECMAKE = " \
    -DCMAKE_BUILD_TYPE=Release \
    -DQT_HOST_PATH=${RECIPE_SYSROOT_NATIVE}${prefix_native} \
"

do_install:append() {
    # Install application to medtech prefix
    install -d ${D}/opt/medtech/clinician-ui
    if [ -f ${D}${bindir}/clinician-ui ]; then
        mv ${D}${bindir}/clinician-ui ${D}/opt/medtech/clinician-ui/clinician-ui
    fi

    # Install Qt platform configuration
    install -d ${D}${sysconfdir}/medtech
    install -m 0644 ${WORKDIR}/qt-config.conf ${D}${sysconfdir}/medtech/qt-config.conf
    install -m 0644 ${WORKDIR}/clinician-ui.env ${D}${sysconfdir}/medtech/clinician-ui.env

    # Install systemd service
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/clinician-ui.service ${D}${systemd_system_unitdir}/medtech-clinician-ui.service
}

FILES:${PN} = " \
    /opt/medtech/clinician-ui \
    ${sysconfdir}/medtech/clinician-ui.env \
    ${sysconfdir}/medtech/qt-config.conf \
    ${systemd_system_unitdir}/medtech-clinician-ui.service \
"
