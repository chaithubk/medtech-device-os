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

# Ensure non-root build user exists (BitBake sanity check blocks root).
if id -u builder > /dev/null 2>&1; then
    echo "✅ Build user 'builder' already exists"
else
    if [ "$(id -u)" -eq 0 ]; then
        useradd -m -s /bin/bash builder
        echo "✅ Created build user 'builder'"
    else
        echo "⚠️  User 'builder' not found and current user is not root; skipping user creation"
    fi
fi

# Create build directories
mkdir -p yocto/build
mkdir -p yocto/downloads
mkdir -p yocto/sstate-cache

echo "✅ Build directories created"

# Keep workspace writable by the build user when running in the dev container.
if [ "$(id -u)" -eq 0 ] && id -u builder > /dev/null 2>&1; then
    chown -R builder:builder /workspace || true
fi

# Set up Yocto (clone Poky if not exists)
if [ ! -d "yocto/poky" ]; then
    echo ""
    echo "📥 Cloning Poky (Yocto kirkstone)..."
    echo "   This may take 2-5 minutes on first run..."
    echo ""
    
    mkdir -p yocto
    cd yocto

    # Clone with progress. Prefer upstream Yocto; fall back to GitHub mirror
    # in environments where enterprise trust stores break this endpoint's chain.
    if ! git clone --progress -b kirkstone https://git.yoctoproject.org/git/poky poky; then
        echo ""
        echo "⚠️  Upstream Yocto clone failed; trying GitHub mirror..."
        git clone --progress -b kirkstone https://github.com/yoctoproject/poky.git poky
    fi
    
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
echo "  1. Complete local build setup:"
echo "     bash /workspace/scripts/quick-setup.sh"
echo ""
echo "  2. Build directly:"
echo "     bitbake medtech-clinician-ui"
echo "     bitbake core-image-medtech"
echo ""
