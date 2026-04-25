#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
YOCTO_ROOT="$PROJECT_ROOT/yocto"

echo "=== MedTech Device OS Build ==="
echo "Project Root: $PROJECT_ROOT"
echo "Yocto Root: $YOCTO_ROOT"

# Initialize Yocto environment
cd "$YOCTO_ROOT"

if [ ! -d "poky" ]; then
    echo "🔴 Poky not found. Run: source .devcontainer/postCreateCommand"
    exit 1
fi

# Initialize build environment
source poky/oe-init-build-env build

# Copy config templates
if [ ! -f "conf/local.conf" ]; then
    cp ../conf/local.conf.sample conf/local.conf
    echo "Created conf/local.conf from template"
fi

if [ ! -f "conf/bblayers.conf" ]; then
    cp ../conf/bblayers.conf.sample conf/bblayers.conf
    echo "Created conf/bblayers.conf from template"
fi

# Build minimal image
echo "Building core-image-minimal..."
bitbake core-image-minimal

echo "✅ Build complete!"
echo "Image: tmp/deploy/images/qemuarm64/core-image-minimal-qemuarm64.tar.bz2"
