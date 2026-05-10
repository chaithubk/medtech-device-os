#!/bin/bash

# Canonical local setup for dev container Yocto builds.
# This script is idempotent and can be safely re-run.

set -e

SECRETS_DIR="/workspace/.secrets"
DEFAULT_VIGILES_KEY_FILE="$SECRETS_DIR/vigiles-key.txt"
VIGILES_PLACEHOLDER="REPLACE_WITH_VIGILES_KEY_PAYLOAD"

ensure_builder_user() {
    if id -u builder > /dev/null 2>&1; then
        return 0
    fi

    if [ "$(id -u)" -eq 0 ]; then
        useradd -m -s /bin/bash builder
    else
        echo "⚠️  User 'builder' not found and current user is not root; skipping user creation"
    fi
}

bblayers_needs_refresh() {
    local file="$1"

    if [ ! -f "$file" ]; then
        return 0
    fi

    grep -Fq '${TOPDIR}/../meta-openembedded/meta-oe' "$file" \
        && grep -Fq '${TOPDIR}/../meta-openembedded/meta-python' "$file" \
        && grep -Fq '${TOPDIR}/../meta-openembedded/meta-networking' "$file" \
        && grep -Fq '${TOPDIR}/../meta-qt6' "$file" \
        && grep -Fq '${TOPDIR}/../meta-timesys' "$file" \
        && grep -Fq '${TOPDIR}/../meta-medtech' "$file"
}

cd /workspace

echo "🔧 Local Yocto Setup"
echo ""

if ! command -v git > /dev/null 2>&1; then
    echo "❌ git command not found!"
    exit 1
fi

ensure_builder_user

if [ "$(id -u)" -eq 0 ]; then
    ln -sf /workspace/scripts/bitbake /usr/local/bin/bitbake
fi

mkdir -p yocto/build yocto/downloads yocto/sstate-cache

# 1. Ensure all required Yocto repos exist.
echo "📥 Verifying Yocto layers..."
bash scripts/clone-with-retry.sh

# Ensure builder can read git metadata from every layer even if cloned as root.
if [ "$(id -u)" -eq 0 ] && id -u builder > /dev/null 2>&1; then
    chown -R builder:builder /workspace/yocto || true
fi

# 2. Initialize build conf if missing.
mkdir -p yocto/build
cd yocto/build

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

if ! grep -q '^QT_GIT_PROTOCOL = "https"' conf/local.conf; then
    cat <<'EOF' >> conf/local.conf

# Local-only: keep git:// URL form for bitbake git fetcher, but force
# transport over HTTPS to avoid blocked git:// traffic.
QT_GIT_PROTOCOL = "https"
EOF
fi

if ! grep -Eq '(^|\s)INHERIT\s*\+\=\s*"[^"]*\bvigiles\b' conf/local.conf; then
    cat <<'EOF' >> conf/local.conf

# Timesys Vigiles SBOM assessment (free tier)
INHERIT += "vigiles"
EOF
fi

if ! grep -q 'git://code.qt.io/qt/(.*)' conf/local.conf; then
    cat <<'EOF' >> conf/local.conf

# Local-only: if code.qt.io is blocked or has TLS chain issues, fall back to
# the official Qt GitHub mirror for qt/* repositories.
PREMIRRORS:append = " \
git://code.qt.io/qt/(.*) git://github.com/qt/\1;protocol=https \n \
"
EOF
fi

# 3. Bootstrap local Vigiles key file for developer override.
mkdir -p "$SECRETS_DIR"

if [ ! -f "$DEFAULT_VIGILES_KEY_FILE" ]; then
    cat > "$DEFAULT_VIGILES_KEY_FILE" <<EOF
{"email":"REPLACE_WITH_VIGILES_EMAIL","key":"$VIGILES_PLACEHOLDER"}
EOF
fi

chmod 700 "$SECRETS_DIR" || true
chmod 600 "$DEFAULT_VIGILES_KEY_FILE" || true

if [ "$(id -u)" -eq 0 ] && id -u builder > /dev/null 2>&1; then
    chown builder:builder "$SECRETS_DIR" "$DEFAULT_VIGILES_KEY_FILE" || true
fi

if grep -q "$VIGILES_PLACEHOLDER" "$DEFAULT_VIGILES_KEY_FILE"; then
    echo "⚠️  Vigiles key placeholder created at $DEFAULT_VIGILES_KEY_FILE"
    echo "   Replace placeholder text with your real key payload."
else
    echo "✅ Local Vigiles key file detected at $DEFAULT_VIGILES_KEY_FILE"
fi

echo ""
echo "Ready to build! Run:"
echo "  bitbake core-image-medtech"
echo "  bitbake medtech-clinician-ui"
echo ""
