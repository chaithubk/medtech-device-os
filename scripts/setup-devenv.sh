#!/bin/bash

set -e

echo "=== Setting up Yocto Development Environment ==="
echo ""

# Verify we're in workspace
if [ ! -d "/workspace" ]; then
    echo "❌ /workspace directory not found!"
    exit 1
fi

cd /workspace

# Verify git is available
if ! command -v git &> /dev/null; then
    echo "❌ git command not found!"
    echo "   Git must be installed in Dockerfile"
    exit 1
fi

echo "✅ Git available"

# Create build directories
mkdir -p yocto/build
mkdir -p yocto/downloads
mkdir -p yocto/sstate-cache

echo "✅ Build directories created"

# Set up Yocto (clone Poky if not exists)
if [ ! -d "yocto/poky" ]; then
    echo ""
    echo "📥 Cloning Poky (Yocto kirkstone)..."
    echo "   This may take 2-5 minutes on first run..."
    echo ""
    
    mkdir -p yocto
    cd yocto
    
    # Clone with progress
    git clone --progress -b kirkstone https://git.yoctoproject.org/git/poky poky
    
    cd ..
    echo ""
    echo "✅ Poky cloned successfully"
else
    echo "✅ Poky already exists"
fi

echo ""
echo "=== ✅ Yocto environment ready! ==="
echo ""
echo "Next steps:"
echo "  1. Initialize build environment:"
echo "     source /workspace/yocto/poky/oe-init-build-env /workspace/yocto/build"
echo ""
echo "  2. Copy configuration templates:"
echo "     cp ../conf/local.conf.sample conf/local.conf"
echo "     cp ../conf/bblayers.conf.sample conf/bblayers.conf"
echo ""
echo "  3. Build minimal image:"
echo "     bitbake core-image-minimal"
echo ""
