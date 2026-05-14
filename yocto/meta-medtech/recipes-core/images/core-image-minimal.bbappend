# core-image-minimal.bbappend
# Align minimal image SSH onboarding with MedTech image defaults.

inherit extrausers

MEDTECH_ADMIN_USER ?= "medadmin"
MEDTECH_ADMIN_AUTHORIZED_KEY ?= ""
MEDTECH_ADMIN_KEY_FILE ?= "/workspace/.secrets/medtech-admin-key.pub"
MEDTECH_ADMIN_PASSWORD_HASH ?= "*"

# Include first-boot key provisioning and sudo support for medadmin.
IMAGE_INSTALL:append = " sudo firstboot-ssh-setup"

EXTRA_USERS_PARAMS:append = " \
    useradd -m -d /home/${MEDTECH_ADMIN_USER} -s /bin/sh ${MEDTECH_ADMIN_USER}; \
    usermod -p '${MEDTECH_ADMIN_PASSWORD_HASH}' ${MEDTECH_ADMIN_USER}; \
    groupadd -f systemd-journal; \
    usermod -a -G adm,systemd-journal,sudo ${MEDTECH_ADMIN_USER}; \
    usermod -p '!' root; \
"

IMAGE_PREPROCESS_COMMAND:append = " medtech_minimal_provision_admin_key; medtech_minimal_configure_sudo; "

medtech_minimal_provision_admin_key() {
    local admin_home="${IMAGE_ROOTFS}/home/${MEDTECH_ADMIN_USER}"
    local key="${MEDTECH_ADMIN_AUTHORIZED_KEY}"
    local key_file="${MEDTECH_ADMIN_KEY_FILE}"

    # Prefer explicit override; otherwise use first non-comment key line.
    if [ -z "$key" ] && [ -f "$key_file" ]; then
        key="$(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$key_file" | grep -v 'REPLACE_WITH_MEDTECH_ADMIN_PUBLIC_KEY' | head -n 1 || true)"
    fi

    if [ -n "$key" ]; then
        install -d -m 0700 "$admin_home/.ssh"
        printf '%s\n' "$key" > "$admin_home/.ssh/authorized_keys"
        chmod 0600 "$admin_home/.ssh/authorized_keys"
        chown -R ${MEDTECH_ADMIN_USER}:${MEDTECH_ADMIN_USER} "$admin_home/.ssh"
    fi
}

medtech_minimal_configure_sudo() {
    install -d ${IMAGE_ROOTFS}/etc/sudoers.d
    cat > ${IMAGE_ROOTFS}/etc/sudoers.d/90-medtech-admin << EOF
${MEDTECH_ADMIN_USER} ALL=(ALL) NOPASSWD:ALL
EOF
    chmod 0440 ${IMAGE_ROOTFS}/etc/sudoers.d/90-medtech-admin
}
