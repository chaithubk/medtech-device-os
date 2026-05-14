#!/bin/bash
# Boot MedTech Device OS image in QEMU ARM64 emulator
# Usage: bash scripts/run-qemu.sh [--graphics]
#        (default: nographic mode; use --graphics for GUI)

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
YOCTO_ROOT="$PROJECT_ROOT/yocto"
BUILD_DIR="$YOCTO_ROOT/build"
DEPLOY_DIR="$BUILD_DIR/tmp/deploy/images/qemuarm64"
EXTRACTED_IMAGE_DIR="$PROJECT_ROOT/qemu-release/extracted/payload/image"
ARTIFACTS_DIR="$PROJECT_ROOT/artifacts"

echo "=== MedTech Device OS - QEMU Runner ==="

IMAGE_NAME="core-image-medtech"
GRAPHICS="-nographic"
DRY_RUN=0
SSH_PORT=2222

while [[ $# -gt 0 ]]; do
    case "$1" in
        --graphics)
            GRAPHICS="-display gtk"
            shift
            ;;
        --image-name)
            IMAGE_NAME="${2:-}"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --ssh-port)
            SSH_PORT="${2:-}"
            shift 2
            ;;
        -h|--help)
            echo "Usage: bash scripts/run-qemu.sh [--graphics] [--image-name <pn>] [--ssh-port <port>] [--dry-run]"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            exit 2
            ;;
    esac
done

# Check for required binaries
if ! command -v qemu-system-aarch64 &> /dev/null; then
    echo "❌ qemu-system-aarch64 not found"
    exit 1
fi

if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
    echo "❌ Invalid --ssh-port value: $SSH_PORT"
    echo "Expected an integer between 1 and 65535"
    exit 2
fi

is_port_in_use() {
    local port="$1"

    if command -v ss >/dev/null 2>&1; then
        ss -ltn "( sport = :$port )" 2>/dev/null | grep -q ":$port"
        return
    fi

    if command -v lsof >/dev/null 2>&1; then
        lsof -iTCP:"$port" -sTCP:LISTEN -n -P >/dev/null 2>&1
        return
    fi

    # If no probe utility exists, assume free and let QEMU report conflicts.
    return 1
}

if is_port_in_use "$SSH_PORT"; then
    if [ "$SSH_PORT" -ne 2222 ]; then
        echo "❌ Requested SSH host port is already in use: $SSH_PORT"
        echo "Choose a different port with --ssh-port <port>"
        exit 1
    fi

    for candidate in 2223 2224 2225 2226 2227 2228 2229 2230 2231 2232; do
        if ! is_port_in_use "$candidate"; then
            echo "⚠️  Host port 2222 is already in use; using $candidate instead"
            SSH_PORT="$candidate"
            break
        fi
    done

    if [ "$SSH_PORT" -eq 2222 ]; then
        echo "❌ Host port 2222 is in use and no fallback port is free in 2223-2232"
        echo "Stop the process using 2222, or run with --ssh-port <free-port>"
        exit 1
    fi
fi

pick_latest_in_dir() {
    local dir="$1"
    local pattern="$2"

    find -L "$dir" -maxdepth 1 \( -type f -o -type l \) -name "$pattern" -printf '%T@ %p\n' 2>/dev/null \
        | sort -nr \
        | head -n 1 \
        | cut -d' ' -f2-
}

pick_latest() {
    local pattern="$1"

    pick_latest_in_dir "$IMAGE_DIR" "$pattern"
}

extract_bundle_if_needed() {
    local bundle=""

    if [ -d "$EXTRACTED_IMAGE_DIR" ]; then
        if [ -n "$(pick_latest_in_dir "$EXTRACTED_IMAGE_DIR" 'Image*' || true)" ] && [ -n "$(pick_latest_in_dir "$EXTRACTED_IMAGE_DIR" '*.ext4' || true)" ]; then
            return 0
        fi
    fi

    bundle="$(find "$ARTIFACTS_DIR" -maxdepth 1 -type f -name '*qemuarm64-bundle.tar.gz' | head -n 1 2>/dev/null || true)"
    if [ -z "$bundle" ]; then
        return 1
    fi

    echo "Extracted artifact payload missing or incomplete."
    echo "Extracting bundle: $bundle"
    mkdir -p "$PROJECT_ROOT/qemu-release/extracted"
    tar -xzf "$bundle" -C "$PROJECT_ROOT/qemu-release/extracted"
}

resolve_image_dir() {
    if [ -d "$DEPLOY_DIR" ]; then
        if [ -n "$(pick_latest_in_dir "$DEPLOY_DIR" 'Image*' || true)" ] && [ -n "$(pick_latest_in_dir "$DEPLOY_DIR" '*.ext4' || true)" ]; then
            IMAGE_DIR="$DEPLOY_DIR"
            IMAGE_SOURCE="local build output"
            return 0
        fi
    fi

    if [ -d "$EXTRACTED_IMAGE_DIR" ]; then
        if [ -n "$(pick_latest_in_dir "$EXTRACTED_IMAGE_DIR" 'Image*' || true)" ] && [ -n "$(pick_latest_in_dir "$EXTRACTED_IMAGE_DIR" '*.ext4' || true)" ]; then
            IMAGE_DIR="$EXTRACTED_IMAGE_DIR"
            IMAGE_SOURCE="extracted artifact payload"
            return 0
        fi
    fi

    if extract_bundle_if_needed; then
        if [ -n "$(pick_latest_in_dir "$EXTRACTED_IMAGE_DIR" 'Image*' || true)" ] && [ -n "$(pick_latest_in_dir "$EXTRACTED_IMAGE_DIR" '*.ext4' || true)" ]; then
            IMAGE_DIR="$EXTRACTED_IMAGE_DIR"
            IMAGE_SOURCE="artifact bundle (auto-extracted)"
            return 0
        fi
    fi

    return 1
}

IMAGE_DIR=""
IMAGE_SOURCE=""

if ! resolve_image_dir; then
    echo "❌ No bootable image source found"
    echo "Checked local build output: $DEPLOY_DIR"
    echo "Checked extracted artifacts: $EXTRACTED_IMAGE_DIR"
    echo "Checked bundle tarball in: $ARTIFACTS_DIR"
    echo "Try: bash scripts/download-and-run-qemu.sh"
    exit 1
fi

echo "Image source: $IMAGE_SOURCE"
echo "Image dir   : $IMAGE_DIR"

KERNEL="$IMAGE_DIR/Image-qemuarm64.bin"
if [[ ! -e "$KERNEL" ]]; then
    KERNEL="$(pick_latest 'Image*qemuarm64*.bin')"
fi
if [[ -z "$KERNEL" ]]; then
    KERNEL="$(pick_latest 'Image')"
fi
if [[ -z "$KERNEL" ]]; then
    KERNEL="$(pick_latest 'Image*')"
fi

ROOTFS="$IMAGE_DIR/${IMAGE_NAME}-qemuarm64.ext4"
if [[ ! -e "$ROOTFS" ]]; then
    ROOTFS="$(pick_latest "${IMAGE_NAME}-qemuarm64*.rootfs.ext4")"
fi
if [[ -z "$ROOTFS" ]]; then
    ROOTFS="$(pick_latest "${IMAGE_NAME}-qemuarm64*.ext4")"
fi
if [[ -z "$ROOTFS" ]]; then
    ROOTFS="$(pick_latest '*.ext4')"
fi

if [ -n "$ROOTFS" ] && [[ "$ROOTFS" == *.wic* ]]; then
    echo "❌ Found disk image but not ext4 rootfs: $ROOTFS"
    echo "This runner expects an ext4 image for -drive format=raw."
    exit 1
fi

if [ -n "$ROOTFS" ] && [ ! -f "$ROOTFS" ]; then
    ROOTFS=""
fi

if [ -z "$ROOTFS" ] && [ "$IMAGE_DIR" = "$EXTRACTED_IMAGE_DIR" ]; then
    echo "❌ No ext4 rootfs found in extracted payload image directory: $EXTRACTED_IMAGE_DIR"
    echo "Re-extract the bundle or use: bash scripts/download-and-run-qemu.sh"
    exit 1
fi

if [ -z "$ROOTFS" ]; then
    ROOTFS="$(pick_latest "${IMAGE_NAME}-qemuarm64*.ext4")"
fi

if [ -z "$KERNEL" ] || [ ! -f "$KERNEL" ]; then
    echo "❌ Kernel not found: $KERNEL"
    echo "Build the image first: bitbake core-image-medtech"
    echo "Or download/extract release bundle via: bash scripts/download-and-run-qemu.sh"
    exit 1
fi

if [ -z "$ROOTFS" ] || [ ! -f "$ROOTFS" ]; then
    echo "❌ Rootfs not found: $ROOTFS"
    echo "Build the image first: bitbake core-image-medtech"
    echo "Or download/extract release bundle via: bash scripts/download-and-run-qemu.sh"
    exit 1
fi

echo "Kernel : $KERNEL"
echo "Rootfs : $ROOTFS"
echo "Graphics: ${GRAPHICS// /}"
echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                   MedTech Device OS - First Boot                   ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "On first boot, an interactive SSH key provisioning wizard opens on ttyAMA0."
echo "No default medadmin password is enabled in the image."
echo ""
echo "Provide your SSH public key when prompted to enable SSH access."
echo "After provisioning, password login is permanently disabled."
echo ""
echo "See: docs/guides/first-boot-setup.md for complete instructions."
echo ""
echo "Once SSH key is provisioned, connect from host:"
echo "  ssh -i ~/.ssh/id_medtech -p ${SSH_PORT} medadmin@localhost"
echo ""
echo "To quit QEMU: Ctrl+A then X (or: shutdown -h now)"
echo ""

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "Dry run enabled."
    exit 0
fi

# Boot QEMU with ARM64 VM configuration
exec qemu-system-aarch64 \
    -machine virt \
    -cpu cortex-a57 \
    -smp 4 \
    -m 256 \
    -kernel "$KERNEL" \
    -drive id=disk0,file="$ROOTFS",if=none,format=raw \
    -device virtio-blk-pci,drive=disk0,romfile= \
    -device virtio-net-pci,netdev=net0,mac=52:54:00:12:34:02,romfile= \
    -netdev user,id=net0,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22 \
    -device qemu-xhci \
    -device usb-tablet \
    -device usb-kbd \
    -device virtio-gpu-pci \
    -object rng-random,filename=/dev/urandom,id=rng0 \
    -device virtio-rng-pci,rng=rng0 \
    $GRAPHICS \
    -append "root=/dev/vda rw console=ttyAMA0,115200"

