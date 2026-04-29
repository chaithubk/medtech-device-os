#!/bin/bash
# build-robust.sh
# Production-grade local build entry-point.
# Runs pre-flight → layer clone → bitbake with diagnostics.
# In CI, the individual subscripts are called as separate steps instead.

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
YOCTO_DIR="$PROJECT_ROOT/yocto"
BUILD_DIR="$YOCTO_DIR/build"

echo "=== MedTech Device OS — Robust Build ==="
echo ""

# ── Step 1: Pre-flight ────────────────────────────────────────────────────────
echo "--- Step 1/5: Pre-flight checks ---"
bash "$SCRIPT_DIR/preflight-check.sh" || {
    echo "FAIL: Pre-flight checks failed — aborting."
    exit 1
}
echo ""

# ── Step 2: Clone layers ──────────────────────────────────────────────────────
echo "--- Step 2/5: Clone/verify Yocto layers ---"
bash "$SCRIPT_DIR/clone-with-retry.sh" || {
    echo "FAIL: Layer cloning failed — aborting."
    exit 1
}
echo ""

# ── Step 3: Initialise build environment ─────────────────────────────────────
echo "--- Step 3/5: Initialise build environment ---"

if [ ! -f "$YOCTO_DIR/poky/oe-init-build-env" ]; then
    echo "FAIL: $YOCTO_DIR/poky/oe-init-build-env not found."
    exit 1
fi

# oe-init-build-env must be sourced; it changes cwd to BUILD_DIR
mkdir -p "$BUILD_DIR"
cd "$YOCTO_DIR"
# shellcheck disable=SC1091
source poky/oe-init-build-env build > /dev/null 2>&1

if [ ! -f "conf/local.conf" ]; then
    cp ../conf/local.conf.sample conf/local.conf
    echo "   Created conf/local.conf from template"
fi
if [ ! -f "conf/bblayers.conf" ]; then
    cp ../conf/bblayers.conf.sample conf/bblayers.conf
    echo "   Created conf/bblayers.conf from template"
fi
if ! grep -q '^QT_GIT_PROTOCOL = "https"' conf/local.conf; then
    cat <<'EOF' >> conf/local.conf

# Local-only: keep git:// URL form for bitbake git fetcher, but force
# transport over HTTPS to avoid blocked git:// traffic.
QT_GIT_PROTOCOL = "https"
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
echo "   OK: build directory ready at $BUILD_DIR"
echo ""

# ── Step 4: Disk space check before the long build ───────────────────────────
echo "--- Step 4/5: Final resource check ---"
AVAIL_KB=$(df . | awk 'NR==2 {print $4}')
AVAIL_GB=$(( AVAIL_KB / 1024 / 1024 ))
echo "   Disk available for build: ${AVAIL_GB} GB"
if [ "$AVAIL_GB" -lt 20 ]; then
    echo "   WARNING: very low disk space — build is likely to fail"
fi
echo ""

# ── Step 5: BitBake ───────────────────────────────────────────────────────────
echo "--- Step 5/5: BitBake ---"
echo "   Target : core-image-medtech"
echo "   Machine: ${MACHINE:-qemuarm64}"
echo "   Log    : $BUILD_DIR/build.log"
echo ""

BUILD_START=$(date +%s)

# -k: continue building other targets even if one fails (collect all errors)
set +e
bitbake -k core-image-medtech 2>&1 | tee build.log
BITBAKE_EXIT=${PIPESTATUS[0]}
set -e

BUILD_END=$(date +%s)
BUILD_MIN=$(( (BUILD_END - BUILD_START) / 60 ))

echo ""
echo "========================================="

IMAGE="tmp/deploy/images/qemuarm64/core-image-medtech-qemuarm64.ext4"

if [ "$BITBAKE_EXIT" -eq 0 ] && [ -f "$IMAGE" ]; then
    SIZE=$(du -sh "$IMAGE" | cut -f1)
    echo "OK: Build succeeded in ${BUILD_MIN} minutes"
    echo "    Image : $IMAGE ($SIZE)"
    echo ""
    echo "Next steps:"
    echo "  Process SBOM : bash $SCRIPT_DIR/process-sbom.sh"
    echo "  Boot QEMU    : runqemu qemuarm64 core-image-medtech nographic"
    exit 0
else
    echo "FAIL: Build failed (exit $BITBAKE_EXIT) after ${BUILD_MIN} minutes"
    echo ""
    echo "Diagnostics:"
    echo "  Full log  : $BUILD_DIR/build.log"
    echo "  Last 50   : tail -50 $BUILD_DIR/build.log"
    echo "  Errors    : grep '^ERROR' $BUILD_DIR/build.log"
    echo ""
    echo "Common fixes:"
    echo "  Network error     → re-run; or check proxy/firewall"
    echo "  Disk full         → bitbake -c cleanall core-image-medtech"
    echo "  Missing layer     → bash $SCRIPT_DIR/clone-with-retry.sh"
    echo "  Corrupt sstate    → rm -rf $YOCTO_DIR/sstate-cache && rebuild"
    exit 1
fi
