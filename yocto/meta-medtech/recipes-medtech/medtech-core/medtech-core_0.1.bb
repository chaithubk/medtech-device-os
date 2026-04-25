DESCRIPTION = "MedTech Core Applications"
SUMMARY = "MedTech core application placeholder"
LICENSE = "CLOSED"
PV = "0.1"

S = "${WORKDIR}"

do_compile() {
    echo "Building MedTech Core"
}

do_install() {
    install -d ${D}${bindir}
    # Install binaries here
}

FILES:${PN} = "${bindir}/*"
