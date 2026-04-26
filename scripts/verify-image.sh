#!/bin/bash

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
YOCTO_ROOT="$PROJECT_ROOT/yocto"
BUILD_DIR="$YOCTO_ROOT/build"
DEPLOY_DIR="$BUILD_DIR/tmp/deploy/images/qemuarm64"

echo "=== MedTech Device OS Image Verification ==="
echo ""

# Check 1: Image exists
if [ ! -f "$DEPLOY_DIR/core-image-medtech-qemuarm64.ext4" ]; then
    echo "❌ Image not found: $DEPLOY_DIR/core-image-medtech-qemuarm64.ext4"
    echo "   Run: bitbake core-image-medtech"
    exit 1
fi

echo "✅ Image file exists"

# Check 2: Image size
IMAGE_SIZE=$(du -sh "$DEPLOY_DIR/core-image-medtech-qemuarm64.ext4" | cut -f1)
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

# Check 5: MANIFEST
MANIFEST="$DEPLOY_DIR/core-image-medtech-qemuarm64.manifest"
if [ -f "$MANIFEST" ]; then
    echo "✅ Image manifest found"
    echo ""
    echo "=== Installed Packages (Sample) ==="
    head -10 "$MANIFEST"
    echo "... (see full list in manifest file)"
else
    echo "⚠️  Manifest not found"
fi

echo ""
echo "=== Checking for medtech services ==="

for svc in mosquitto vitals-publisher edge-analytics clinician-ui; do
    if grep -q "$svc" "$MANIFEST" 2>/dev/null; then
        echo "✅ $svc included"
    else
        echo "⚠️  $svc not found (check recipe dependencies)"
    fi
done

echo ""
echo "=== Image Ready ==="
echo ""
echo "To boot in QEMU:"
echo "  cd $BUILD_DIR"
echo "  runqemu qemuarm64 core-image-medtech nographic"
echo ""
echo "Inside QEMU, sanity checks:"
echo "  systemctl status mosquitto medtech-vitals-publisher medtech-edge-analytics medtech-clinician-ui"
echo "  mosquitto_sub -t 'medtech/#' -v   # Should receive vitals + predictions"
echo "  journalctl -u medtech-vitals-publisher -n 50"
echo ""
