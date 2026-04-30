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

echo "=== MedTech Device OS - QEMU Runner ==="

IMAGE_NAME="core-image-medtech"
GRAPHICS="-nographic"
DRY_RUN=0

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
        -h|--help)
            echo "Usage: bash scripts/run-qemu.sh [--graphics] [--image-name <pn>] [--dry-run]"
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

pick_latest() {
    local pattern="$1"

    find -L "$DEPLOY_DIR" -maxdepth 1 \( -type f -o -type l \) -name "$pattern" -printf '%T@ %p\n' 2>/dev/null \
        | sort -nr \
        | head -n 1 \
        | cut -d' ' -f2-
}

KERNEL="$DEPLOY_DIR/Image-qemuarm64.bin"
if [[ ! -e "$KERNEL" ]]; then
    KERNEL="$(pick_latest 'Image*qemuarm64*.bin')"
fi
if [[ -z "$KERNEL" ]]; then
    KERNEL="$(pick_latest 'Image')"
fi
if [[ -z "$KERNEL" ]]; then
    KERNEL="$(pick_latest 'Image*')"
fi

ROOTFS="$DEPLOY_DIR/${IMAGE_NAME}-qemuarm64.ext4"
if [[ ! -e "$ROOTFS" ]]; then
    ROOTFS="$(pick_latest "${IMAGE_NAME}-qemuarm64*.rootfs.ext4")"
fi
if [[ -z "$ROOTFS" ]]; then
    ROOTFS="$(pick_latest "${IMAGE_NAME}-qemuarm64*.ext4")"
fi

if [ -z "$KERNEL" ] || [ ! -f "$KERNEL" ]; then
    echo "❌ Kernel not found: $KERNEL"
    echo "Build the image first: bash scripts/build-robust.sh"
    exit 1
fi

if [ -z "$ROOTFS" ] || [ ! -f "$ROOTFS" ]; then
    echo "❌ Rootfs not found: $ROOTFS"
    echo "Build the image first: bash scripts/build-robust.sh"
    exit 1
fi

echo "Kernel : $KERNEL"
echo "Rootfs : $ROOTFS"
echo "Graphics: ${GRAPHICS// /}"
echo ""
echo "Login as: root"
echo "Password: root"
echo "Quit: Ctrl+A then X (or: shutdown -h now)"
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
    -device virtio-blk-pci,drive=disk0 \
    -device virtio-net-pci,netdev=net0,mac=52:54:00:12:34:02 \
    -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22 \
    -device qemu-xhci \
    -device usb-tablet \
    -device usb-kbd \
    -device virtio-gpu-pci \
    -object rng-random,filename=/dev/urandom,id=rng0 \
    -device virtio-rng-pci,rng=rng0 \
    $GRAPHICS \
    -append "root=/dev/vda rw console=ttyAMA0,115200"

