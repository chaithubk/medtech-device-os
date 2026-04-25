#!/bin/bash

# Quick setup for QEMU building
# Run this once after reopening container

set -e

cd /workspace

echo "🔧 Quick Yocto Setup"
echo ""

# 1. Verify Poky
if [ ! -d "yocto/poky" ]; then
    echo "❌ Poky not found. Run setup-devenv.sh first"
    exit 1
fi

cd yocto/build

# 2. Initialize build env
if [ ! -f "conf/local.conf" ]; then
    echo "📋 Initializing build environment..."
    source ../poky/oe-init-build-env . > /dev/null 2>&1
    
    echo "📋 Copying configuration..."
    cp ../conf/local.conf.sample conf/local.conf
    cp ../conf/bblayers.conf.sample conf/bblayers.conf
    
    echo "✅ Build environment ready"
fi

# 3. Show next step
echo ""
echo "Ready to build! Run:"
echo "  cd /workspace/yocto/build"
echo "  bitbake core-image-minimal"
echo ""
