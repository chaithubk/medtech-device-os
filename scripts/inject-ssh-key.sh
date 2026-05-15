#!/bin/bash
# Inject an SSH public key directly into a MedTech Device OS ext4 rootfs image.
#
# Use this when the first-boot SSH provisioning wizard did not prompt for a key
# (e.g., using a pre-built release artifact on a host where the first-boot wizard
# exited before your input arrived).
#
# Requires: Linux host, root/sudo access (for loopback mount).
#
# Usage:
#   bash scripts/inject-ssh-key.sh [--rootfs <path>] [--key <pubkey-file>]
#   bash scripts/inject-ssh-key.sh                  # auto-detects rootfs and key

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# ── Defaults ─────────────────────────────────────────────────────────────────
ROOTFS_PATH=""
KEY_PATH=""
MEDTECH_USER="medadmin"
MEDTECH_UID=1000
MEDTECH_GID=1000
DRY_RUN=0

# ── CLI parsing ───────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: bash scripts/inject-ssh-key.sh [options]

Options:
  --rootfs <path>   Path to ext4 rootfs image (auto-detected if omitted)
  --key <path>      Path to SSH public key file (default: ~/.ssh/id_medtech.pub)
  --dry-run         Print what would be done without modifying the image
  -h, --help        Show this help

Examples:
  bash scripts/inject-ssh-key.sh
  bash scripts/inject-ssh-key.sh --key ~/.ssh/id_ed25519.pub
  bash scripts/inject-ssh-key.sh --rootfs /path/to/core-image-medtech.ext4
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rootfs) ROOTFS_PATH="$2"; shift 2 ;;
        --key)    KEY_PATH="$2";    shift 2 ;;
        --dry-run) DRY_RUN=1;       shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1"; usage; exit 2 ;;
    esac
done

log()   { echo "[inject-ssh-key] $*"; }
error() { echo "[inject-ssh-key] ERROR: $*" >&2; }
die()   { error "$*"; exit 1; }

# ── Auto-detect rootfs ────────────────────────────────────────────────────────
if [[ -z "$ROOTFS_PATH" ]]; then
    # 1. Extracted artifact payload
    CANDIDATE="$(find "$PROJECT_ROOT/qemu-release/extracted/payload/image" \
        -maxdepth 1 -name '*.ext4' 2>/dev/null | sort | tail -n 1 || true)"

    # 2. Local Yocto build output
    if [[ -z "$CANDIDATE" ]]; then
        CANDIDATE="$(find "$PROJECT_ROOT/yocto/build/tmp/deploy/images/qemuarm64" \
            -maxdepth 1 -name 'core-image-medtech*.ext4' 2>/dev/null | sort | tail -n 1 || true)"
    fi

    if [[ -z "$CANDIDATE" ]]; then
        die "No ext4 rootfs found. Use --rootfs <path> to specify one.
Searched:
  $PROJECT_ROOT/qemu-release/extracted/payload/image/
  $PROJECT_ROOT/yocto/build/tmp/deploy/images/qemuarm64/"
    fi
    ROOTFS_PATH="$CANDIDATE"
fi

[[ -f "$ROOTFS_PATH" ]] || die "Rootfs not found: $ROOTFS_PATH"

# ── Auto-detect public key ────────────────────────────────────────────────────
if [[ -z "$KEY_PATH" ]]; then
    for candidate in ~/.ssh/id_medtech.pub ~/.ssh/id_ed25519.pub ~/.ssh/id_rsa.pub; do
        if [[ -f "$candidate" ]]; then
            KEY_PATH="$candidate"
            break
        fi
    done
fi

[[ -n "$KEY_PATH" ]] || die "No SSH public key found. Use --key <path> or generate one:
  ssh-keygen -t ed25519 -f ~/.ssh/id_medtech -N \"\" -C \"medtech@device\""
[[ -f "$KEY_PATH" ]] || die "Key file not found: $KEY_PATH"

# ── Validate key format ───────────────────────────────────────────────────────
PUBKEY="$(cat "$KEY_PATH")"
if ! echo "$PUBKEY" | grep -Eq '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) '; then
    die "Invalid SSH public key format in: $KEY_PATH
Expected a line starting with ssh-ed25519, ssh-rsa, or ecdsa-sha2-*."
fi

# ── Check required tools ──────────────────────────────────────────────────────
if ! command -v mount &>/dev/null; then
    die "mount command not found. This script requires a Linux host with loopback mount support."
fi

# ── Summary ───────────────────────────────────────────────────────────────────
log "Rootfs  : $ROOTFS_PATH"
log "Key file: $KEY_PATH"
log "Key     : $(echo "$PUBKEY" | cut -c1-60)..."
echo ""

if [[ "$DRY_RUN" -eq 1 ]]; then
    log "Dry run — no changes made."
    exit 0
fi

# ── Need root ─────────────────────────────────────────────────────────────────
SUDO=""
if [[ "$(id -u)" -ne 0 ]]; then
    if command -v sudo &>/dev/null; then
        SUDO="sudo"
        log "Root access needed for loopback mount — will use sudo."
    else
        die "This script must be run as root (or with sudo) to mount the ext4 image."
    fi
fi

# ── Mount, inject, unmount ────────────────────────────────────────────────────
MOUNT_DIR="$(mktemp -d)"
cleanup() {
    if mountpoint -q "$MOUNT_DIR" 2>/dev/null; then
        $SUDO umount "$MOUNT_DIR" 2>/dev/null || true
    fi
    rmdir "$MOUNT_DIR" 2>/dev/null || true
}
trap cleanup EXIT

log "Mounting $ROOTFS_PATH …"
$SUDO mount -o loop "$ROOTFS_PATH" "$MOUNT_DIR"

SSH_DIR="$MOUNT_DIR/home/${MEDTECH_USER}/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

$SUDO mkdir -p "$SSH_DIR"
echo "$PUBKEY" | $SUDO tee "$AUTH_KEYS" > /dev/null
$SUDO chown -R "${MEDTECH_UID}:${MEDTECH_GID}" "$MOUNT_DIR/home/${MEDTECH_USER}/.ssh"
$SUDO chmod 700 "$SSH_DIR"
$SUDO chmod 600 "$AUTH_KEYS"

log "Unmounting …"
$SUDO umount "$MOUNT_DIR"

echo ""
log "Done. SSH public key injected into rootfs."
log "Boot the image and connect via:"
log "  ssh -i ${KEY_PATH%.pub} -p 2222 ${MEDTECH_USER}@localhost"
