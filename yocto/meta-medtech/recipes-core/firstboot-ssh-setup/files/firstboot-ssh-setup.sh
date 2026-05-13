#!/bin/bash
# First-boot SSH key provisioning for medadmin account
# This script runs once on first boot via systemd service.
# User can paste their SSH public key, which is then written to authorized_keys.
# After successful key provisioning, password login is disabled.

set -e

MEDTECH_ADMIN_USER="medadmin"
ADMIN_HOME="/home/${MEDTECH_ADMIN_USER}"
SSH_DIR="${ADMIN_HOME}/.ssh"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"
PROMPT_TIMEOUT_SECONDS="${PROMPT_TIMEOUT_SECONDS:-120}"

log() {
    echo "[firstboot-ssh-setup] $*"
}

error() {
    echo "[firstboot-ssh-setup] ERROR: $*" >&2
}

ensure_ssh_dir() {
    if [ ! -d "$SSH_DIR" ]; then
        mkdir -p "$SSH_DIR"
        chmod 700 "$SSH_DIR"
        chown "${MEDTECH_ADMIN_USER}:${MEDTECH_ADMIN_USER}" "$SSH_DIR"
        log "Created .ssh directory"
    fi
}

prompt_for_key() {
    clear
    cat <<'EOF'
╔════════════════════════════════════════════════════════════════════╗
║                    MedTech Device OS - First Boot                  ║
║                   SSH Key Provisioning Setup                       ║
╚════════════════════════════════════════════════════════════════════╝

To enable secure SSH access, you need to provide your SSH public key.

This is a ONE-TIME setup. After you provision your SSH public key:
  1. Password login will be permanently disabled
  2. SSH key-only access will be available
    3. This setup wizard will not run again

IMPORTANT: You must have the PRIVATE key on your host to connect after this.

═══════════════════════════════════════════════════════════════════════

Step 1: On your HOST computer, generate an SSH key if you don't have one:
  ssh-keygen -t ed25519 -f ~/.ssh/id_medtech -N "" -C "medtech@device"

Step 2: Display your PUBLIC key:
  cat ~/.ssh/id_medtech.pub

Step 3: Copy the ENTIRE output from Step 2 and paste it below.
        (It should start with "ssh-ed25519", "ssh-rsa", or similar)

Press Enter when ready to paste your SSH public key:
EOF
    if ! read -r -t "$PROMPT_TIMEOUT_SECONDS"; then
        log "No serial input detected within ${PROMPT_TIMEOUT_SECONDS}s; skipping for now (service will retry on next boot until key is provisioned)"
        log "SSH remains key-only and no key is installed yet. If serial console is unavailable, rebuild with ssh_access_mode=internal-keyed and provide MEDTECH_ADMIN_SSH_PUBLIC_KEY in workflow secrets."
        return 1
    fi
}

read_public_key() {
    local key=""
    log "Paste your SSH public key (single line):"
    if ! read -r -t "$PROMPT_TIMEOUT_SECONDS" key; then
        error "Timed out waiting for SSH public key input"
        return 1
    fi
    
    # Trim whitespace
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    
    if [ -z "$key" ]; then
        error "No SSH public key provided"
        return 1
    fi
    
    echo "$key"
}

validate_ssh_key() {
    local key="$1"
    
    # Check for SSH key markers
    if ! printf '%s\n' "$key" | grep -Eq '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) '; then
        error "Invalid SSH public key format. Expected format: ssh-ed25519 AAAA... or ssh-rsa AAAA..."
        return 1
    fi
    
    return 0
}

provision_key() {
    local key="$1"
    
    ensure_ssh_dir
    
    log "Writing SSH public key to authorized_keys"
    printf '%s\n' "$key" > "$AUTHORIZED_KEYS"
    chmod 600 "$AUTHORIZED_KEYS"
    chown "${MEDTECH_ADMIN_USER}:${MEDTECH_ADMIN_USER}" "$AUTHORIZED_KEYS"
    
    log "SSH public key provisioned successfully"
}

disable_password_login() {
    log "Disabling password-based login for ${MEDTECH_ADMIN_USER}"
    usermod -p '*' "$MEDTECH_ADMIN_USER"
    log "Password login disabled"
}

show_summary() {
    clear
    cat <<'EOF'
╔════════════════════════════════════════════════════════════════════╗
║               SSH Key Provisioning Complete ✓                      ║
╚════════════════════════════════════════════════════════════════════╝

Your SSH public key has been provisioned successfully.
Password-based login is now PERMANENTLY DISABLED.

Next Steps:
───────────

1. Exit this serial console session (type: exit)

2. From your HOST computer, connect via SSH:
   ssh -i ~/.ssh/id_medtech -p 2222 medadmin@localhost

3. Inside the system, you can use sudo without a password:
   sudo systemctl status mosquitto
   sudo -i

═══════════════════════════════════════════════════════════════════════

If you lose your private key (~/.ssh/id_medtech), you will not be able
to log in to this device. Keep your private key safe.

Press Enter to continue...
EOF
    read -r -t "$PROMPT_TIMEOUT_SECONDS" || true
}

main() {
    log "First-boot SSH key provisioning starting"
    
    # Check if key is already provisioned
    if [ -f "$AUTHORIZED_KEYS" ] && [ -s "$AUTHORIZED_KEYS" ]; then
        log "SSH key already provisioned; skipping setup"
        return 0
    fi
    
    while true; do
        if ! prompt_for_key; then
            log "Continuing boot without interactive key provisioning"
            return 0
        fi
        
        local public_key
        public_key=$(read_public_key) || continue
        
        if ! validate_ssh_key "$public_key"; then
            error "Validation failed. Please try again."
            echo ""
            continue
        fi
        
        log "Key validation passed"
        break
    done
    
    provision_key "$public_key"
    disable_password_login
    show_summary
    
    log "First-boot SSH key provisioning completed successfully"
}

main "$@"
