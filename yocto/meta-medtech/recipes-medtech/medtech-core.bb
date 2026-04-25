DESCRIPTION = "MedTech Core Applications"
LICENSE = "CLOSED"
PV = "0.1.0"

# TODO: Implement recipe with Copilot
# This is a placeholder for Stage 1

S = "${WORKDIR}"

do_compile() {
    echo "Building MedTech Core"
}

do_install() {
    install -d ${D}${bindir}
    # Install binaries here
}

FILES:${PN} = "${bindir}/*"
