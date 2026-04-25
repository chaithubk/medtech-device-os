#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
YOCTO_ROOT="$PROJECT_ROOT/yocto"
BUILD_DIR="$YOCTO_ROOT/build"

echo "=== MedTech Device OS - QEMU Runner ==="

IMAGE="$BUILD_DIR/tmp/deploy/images/qemuarm64/core-image-minimal-qemuarm64.ext4"

if [ ! -f "$IMAGE" ]; then
    echo "❌ Image not found: $IMAGE"
    echo "Run: scripts/build.sh first"
    exit 1
fi

cd "$YOCTO_ROOT"
source poky/oe-init-build-env build > /dev/null 2>&1

echo "🚀 Booting in QEMU..."
runqemu qemuarm64 core-image-minimal nographic

