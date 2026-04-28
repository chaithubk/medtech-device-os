#!/bin/bash
# Boot MedTech Device OS image in QEMU ARM64 emulator
# Usage: bash scripts/run-qemu.sh [--graphics]
#        (default: nographic mode; use --graphics for GUI)

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
YOCTO_ROOT="$PROJECT_ROOT/yocto"
BUILD_DIR="$YOCTO_ROOT/build"
DEPLOY_DIR="$BUILD_DIR/tmp/deploy/images/qemuarm64"

echo "=== MedTech Device OS - QEMU Runner ==="

# Check for required binaries
if ! command -v qemu-system-aarch64 &> /dev/null; then
    echo "❌ qemu-system-aarch64 not found"
    exit 1
fi

# Check for built image
KERNEL="$DEPLOY_DIR/Image-qemuarm64.bin"
ROOTFS="$DEPLOY_DIR/core-image-medtech-qemuarm64.ext4"

if [ ! -f "$KERNEL" ]; then
    echo "❌ Kernel not found: $KERNEL"
    echo "Build the image first: bash scripts/build-robust.sh"
    exit 1
fi

if [ ! -f "$ROOTFS" ]; then
    echo "❌ Rootfs not found: $ROOTFS"
    echo "Build the image first: bash scripts/build-robust.sh"
    exit 1
fi

# Parse arguments
GRAPHICS="-nographic"
if [[ "$*" == *"--graphics"* ]]; then
    GRAPHICS="-display gtk"
fi

echo "Kernel : $KERNEL"
echo "Rootfs : $ROOTFS"
echo "Graphics: ${GRAPHICS// /}"
echo ""
echo "Login as: root"
echo "Password: root"
echo "Quit: Ctrl+A then X (or: shutdown -h now)"
echo ""

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

