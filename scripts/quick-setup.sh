#!/bin/bash

# Quick setup for QEMU building
# Run this once after reopening container

set -e

bblayers_needs_refresh() {
    local file="$1"

    if [ ! -f "$file" ]; then
        return 0
    fi

    grep -Fq '${TOPDIR}/../meta-openembedded/meta-oe' "$file" \
        && grep -Fq '${TOPDIR}/../meta-openembedded/meta-python' "$file" \
        && grep -Fq '${TOPDIR}/../meta-openembedded/meta-networking' "$file" \
        && grep -Fq '${TOPDIR}/../meta-qt6' "$file" \
        && grep -Fq '${TOPDIR}/../meta-medtech' "$file"
}

cd /workspace

echo "🔧 Quick Yocto Setup"
echo ""

# 1. Ensure Poky exists (auto-bootstrap if missing)
if [ ! -d "yocto/poky" ]; then
    echo "📥 Poky not found. Running setup-devenv.sh..."
    bash scripts/setup-devenv.sh
fi

# 2. Ensure all required layers are available.
echo "📥 Verifying Yocto layers..."
bash scripts/clone-with-retry.sh

# Ensure build directory exists before entering it
mkdir -p yocto/build
cd yocto/build

# 3. Initialize or refresh generated local config
if [ ! -f "conf/local.conf" ] || [ ! -f "conf/bblayers.conf" ]; then
    echo "📋 Initializing build environment..."
    source ../poky/oe-init-build-env . > /dev/null 2>&1

    echo "📋 Copying configuration..."
    cp ../conf/local.conf.sample conf/local.conf
    cp ../conf/bblayers.conf.sample conf/bblayers.conf

    echo "✅ Build environment ready"
fi

if ! bblayers_needs_refresh conf/bblayers.conf; then
    echo "📋 Refreshing generated bblayers.conf from sample..."

    if [ -f "conf/bblayers.conf" ]; then
        cp conf/bblayers.conf "conf/bblayers.conf.bak"
    fi

    cp ../conf/bblayers.conf.sample conf/bblayers.conf
fi

if ! grep -q '^CONNECTIVITY_CHECK_URIS = "https://github.com/"' conf/local.conf; then
    cat <<'EOF' >> conf/local.conf

# Local dev-container environments can fail the default Yocto connectivity
# sanity URL certificate chain; use a broadly reachable HTTPS endpoint.
CONNECTIVITY_CHECK_URIS = "https://github.com/"
EOF
fi

# 3. Show next step
echo ""
echo "Ready to build! Run:"
echo "  # Full image build"
echo "  su - builder -c 'cd /workspace && source yocto/poky/oe-init-build-env yocto/build >/dev/null && bitbake core-image-medtech'"
echo ""
echo "  # Single recipe build"
echo "  su - builder -c 'cd /workspace && source yocto/poky/oe-init-build-env yocto/build >/dev/null && bitbake medtech-clinician-ui'"
echo ""
