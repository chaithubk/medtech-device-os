# openssh_%.bbappend — MedTech QEMU/dev SSH policy
#
# Installs an sshd_config.d drop-in that enforces key-only SSH access with
# root login disabled. This keeps the baseline secure in both QEMU and
# production deployments.
#
# Why this recipe?  A dedicated drop-in under /etc/ssh/sshd_config.d/ is the
# minimal, forward-compatible way to apply image policy without modifying
# upstream sshd_config directly.
#
# Security note: account provisioning is handled by medtech-image.bbclass,
# which locks root and provisions a dedicated admin account for key-based SSH.

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " file://medtech-dev-sshd.conf"

do_install:append() {
    install -d ${D}${sysconfdir}/ssh/sshd_config.d
    install -m 0644 ${WORKDIR}/medtech-dev-sshd.conf \
        ${D}${sysconfdir}/ssh/sshd_config.d/10-medtech-dev.conf
}

FILES:${PN} += "${sysconfdir}/ssh/sshd_config.d/10-medtech-dev.conf"
