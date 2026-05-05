# openssh_%.bbappend — MedTech QEMU/dev SSH policy
#
# Installs an sshd_config.d drop-in that enables password-based root login for
# local QEMU developer workflows.  Serial console remains the primary access
# path; SSH on 127.0.0.1:2222 is a working secondary access path.
#
# Why this recipe?  The base Yocto openssh package ships with a conservative
# sshd_config (PermitRootLogin prohibit-password in modern OpenSSH), which
# blocks password authentication for root even though EXTRA_USERS_PARAMS in
# medtech-image.bbclass sets a valid password hash.  Adding a drop-in under
# /etc/ssh/sshd_config.d/ is the minimal, forward-compatible fix — it does not
# touch the upstream default config file and is easy to override or remove for
# production hardening.
#
# Security note: this permissive policy is intentional for a loopback-only QEMU
# guest.  See the file itself for the full security scope statement.

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " file://medtech-dev-sshd.conf"

do_install:append() {
    install -d ${D}${sysconfdir}/ssh/sshd_config.d
    install -m 0600 ${WORKDIR}/medtech-dev-sshd.conf \
        ${D}${sysconfdir}/ssh/sshd_config.d/10-medtech-dev.conf
}

FILES:${PN} += "${sysconfdir}/ssh/sshd_config.d/10-medtech-dev.conf"
