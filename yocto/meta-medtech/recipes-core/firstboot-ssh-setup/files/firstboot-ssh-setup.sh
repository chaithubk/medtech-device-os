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
# 0 means wait indefinitely (strict mode).
PROMPT_TIMEOUT_SECONDS="${PROMPT_TIMEOUT_SECONDS:-0}"
CONSOLE_DEVICE=""

log() {
    echo "[firstboot-ssh-setup] $*"
}

error() {
    echo "[firstboot-ssh-setup] ERROR: $*" >&2
}

open_console_input() {
    local dev=""

    for dev in /dev/ttyAMA0 /dev/ttyS0 /dev/hvc0 /dev/console; do
        if [ -c "$dev" ] && [ -r "$dev" ] && [ -w "$dev" ]; then
            if exec 3<>"$dev"; then
                CONSOLE_DEVICE="$dev"
                log "Using console input device: ${CONSOLE_DEVICE}"
                return 0
            fi
        fi
    done

    if [ -r /dev/stdin ]; then
        exec 3</dev/stdin
        CONSOLE_DEVICE="/dev/stdin"
        log "Using console input fallback: ${CONSOLE_DEVICE}"
        return 0
    fi

    error "No interactive console input is available"
    return 1
}

console_print() {
    # Write directly to the open console FD so messages appear even when
    # kernel printk lines are interleaved on the same ttyAMA0 output.
    printf '%s\r\n' "$*" >&3 2>/dev/null || printf '%s\n' "$*"
}

read_console_line_with_timeout() {
    local __result_var="$1"
    local timeout_seconds="$2"
    local line=""
    local start_time=$SECONDS
    local remaining=0
    local elapsed=0
    local has_timeout=0
    local next_reminder=8   # print first reminder after 8 s

    if [[ "$timeout_seconds" =~ ^[0-9]+$ ]] && [ "$timeout_seconds" -gt 0 ]; then
        has_timeout=1
    fi

    while true; do
        elapsed=$((SECONDS - start_time))
        if [ "$has_timeout" -eq 1 ]; then
            remaining=$((timeout_seconds - elapsed))
            if [ "$remaining" -le 0 ]; then
                return 124
            fi
        else
            remaining=-1
        fi

        if IFS= read -r -t 1 -u 3 line 2>/dev/null; then
            if [ "$__result_var" != "_" ]; then
                printf -v "$__result_var" '%s' "$line"
            fi
            return 0
        fi

        # read returned non-zero without reaching the timeout — the TTY device
        # may not be ready yet this early in boot.  Print a periodic reminder
        # so the user knows the wizard is still alive despite kernel messages
        # flooding the console, then retry.
        elapsed=$((SECONDS - start_time))
        if [ "$elapsed" -ge "$next_reminder" ]; then
            console_print ""
            console_print "══════════════════════════════════════════════════════════════════════"
            console_print " SSH Key Provisioning wizard is WAITING for your input."
            console_print " Press Enter, then paste your SSH public key and press Enter again."
            if [ "$has_timeout" -eq 1 ]; then
                console_print " (${remaining}s remaining before this boot skips setup)"
            else
                console_print " (No timeout configured; boot remains blocked until key is entered)"
            fi
            console_print "══════════════════════════════════════════════════════════════════════"
            next_reminder=$((next_reminder + 10))
        fi

        sleep 1
    done
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
(Kernel boot messages may appear on screen — the wizard is still waiting.)
EOF
    if ! read_console_line_with_timeout _ "$PROMPT_TIMEOUT_SECONDS"; then
        log "No serial input detected within ${PROMPT_TIMEOUT_SECONDS}s"
        log "Reboot and attach to serial console, or set PROMPT_TIMEOUT_SECONDS=0 for strict blocking mode."
        return 1
    fi
}

read_public_key() {
    local key=""
    log "Paste your SSH public key (single line):"
    if ! read_console_line_with_timeout key "$PROMPT_TIMEOUT_SECONDS"; then
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

    while ! open_console_input; do
        error "Console input device unavailable; retrying in 2s"
        sleep 2
    done
    
    while true; do
        if ! prompt_for_key; then
            if [ "$PROMPT_TIMEOUT_SECONDS" -gt 0 ]; then
                log "Continuing boot without interactive key provisioning"
                return 0
            fi

            error "Unexpected prompt failure in strict mode; retrying"
            sleep 2
            continue
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
