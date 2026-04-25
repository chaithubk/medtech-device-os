#!/bin/bash

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
YOCTO_ROOT="$PROJECT_ROOT/yocto"
BUILD_DIR="$YOCTO_ROOT/build"
DEPLOY_DIR="$BUILD_DIR/tmp/deploy/images/qemuarm64"

echo "=== MedTech Device OS Image Verification ==="
echo ""

# Check 1: Image exists
if [ ! -f "$DEPLOY_DIR/core-image-minimal-qemuarm64.ext4" ]; then
    echo "❌ Image not found: $DEPLOY_DIR/core-image-minimal-qemuarm64.ext4"
    echo "   Run: bitbake core-image-minimal"
    exit 1
fi

echo "✅ Image file exists"

# Check 2: Image size
IMAGE_SIZE=$(du -sh "$DEPLOY_DIR/core-image-minimal-qemuarm64.ext4" | cut -f1)
echo "✅ Image size: $IMAGE_SIZE"

# Check 3: Kernel
if [ -f "$DEPLOY_DIR/Image" ]; then
    KERNEL_SIZE=$(du -sh "$DEPLOY_DIR/Image" | cut -f1)
    echo "✅ Kernel: $KERNEL_SIZE"
else
    echo "⚠️  Kernel not found (may use embedded kernel)"
fi

# Check 4: Device tree
if [ -f "$DEPLOY_DIR/qemuarm64.dtb" ]; then
    echo "✅ Device tree found"
else
    echo "⚠️  Device tree not found"
fi

# Check 5: MANIFEST-kernel
if [ -f "$DEPLOY_DIR/core-image-minimal-qemuarm64.manifest" ]; then
    echo "✅ Image manifest found"
    echo ""
    echo "=== Installed Packages (Sample) ==="
    head -10 "$DEPLOY_DIR/core-image-minimal-qemuarm64.manifest"
    echo "... (see full list in manifest file)"
else
    echo "⚠️  Manifest not found"
fi

echo ""
echo "=== Checking for medtech services ==="

# Check for mosquitto
if grep -q "mosquitto" "$DEPLOY_DIR/core-image-minimal-qemuarm64.manifest" 2>/dev/null; then
    echo "✅ MQTT (Mosquitto) included"
else
    echo "⚠️  MQTT not found (add to IMAGE_INSTALL)"
fi

# Check for python
if grep -q "python3" "$DEPLOY_DIR/core-image-minimal-qemuarm64.manifest" 2>/dev/null; then
    echo "✅ Python 3 included"
else
    echo "⚠️  Python 3 not found (add to IMAGE_INSTALL)"
fi

# Check for openssh
if grep -q "openssh" "$DEPLOY_DIR/core-image-minimal-qemuarm64.manifest" 2>/dev/null; then
    echo "✅ SSH (OpenSSH) included"
else
    echo "⚠️  SSH not found (add to IMAGE_INSTALL)"
fi

echo ""
echo "=== Image Ready ==="
echo ""
echo "To boot in QEMU:"
echo "  cd $BUILD_DIR"
echo "  runqemu qemuarm64 core-image-minimal nographic"
echo ""
echo "Inside QEMU, test services:"
echo "  mosquitto -v          # Start MQTT broker"
echo "  python3 --version     # Check Python"
echo "  systemctl status ssh  # Check SSH"
echo ""
