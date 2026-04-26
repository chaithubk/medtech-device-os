#!/bin/bash
# preflight-check.sh
# Validates the host environment before starting an expensive Yocto build.
# Exits non-zero if any hard-failure is found; warns on soft issues.

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Yocto Pre-Flight Checks ==="
echo ""

FAILURES=0

# ── 1. Network & GitHub ───────────────────────────────────────────────────────
echo ">> Checking network connectivity..."

if ! ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
    echo "   WARNING: basic ping to 8.8.8.8 failed (ICMP may be blocked)"
fi

if timeout 10 git ls-remote https://github.com/openembedded/meta-openembedded.git HEAD \
        > /dev/null 2>&1; then
    echo "   OK: GitHub reachable"
else
    echo "   FAIL: Cannot reach GitHub — layer cloning will fail"
    FAILURES=$((FAILURES + 1))
fi

if timeout 10 git ls-remote https://git.yoctoproject.org/git/poky HEAD \
        > /dev/null 2>&1; then
    echo "   OK: yoctoproject.org reachable"
else
    echo "   FAIL: Cannot reach git.yoctoproject.org — Poky clone will fail"
    FAILURES=$((FAILURES + 1))
fi

echo ""

# ── 2. Disk space ─────────────────────────────────────────────────────────────
echo ">> Checking disk space..."

AVAILABLE_KB=$(df "$PROJECT_ROOT" | awk 'NR==2 {print $4}')
AVAILABLE_GB=$(( AVAILABLE_KB / 1024 / 1024 ))
REQUIRED_GB=50   # warn threshold; a full build needs ~80-100 GB

if [ "$AVAILABLE_KB" -lt $(( REQUIRED_GB * 1024 * 1024 )) ]; then
    echo "   WARNING: ${AVAILABLE_GB} GB available — ${REQUIRED_GB} GB recommended for a full build"
else
    echo "   OK: ${AVAILABLE_GB} GB available"
fi

echo ""

# ── 3. Memory ─────────────────────────────────────────────────────────────────
echo ">> Checking memory..."

AVAILABLE_MB=$(free -m | awk 'NR==2 {print $7}')
REQUIRED_MB=4096

if [ "$AVAILABLE_MB" -lt "$REQUIRED_MB" ]; then
    echo "   WARNING: ${AVAILABLE_MB} MB available — ${REQUIRED_MB} MB recommended (build will be slow)"
else
    echo "   OK: ${AVAILABLE_MB} MB available"
fi

echo ""

# ── 4. Required host tools ────────────────────────────────────────────────────
echo ">> Checking required host tools..."

REQUIRED_TOOLS=(git python3 bash curl wget gawk chrpath diffstat)

for tool in "${REQUIRED_TOOLS[@]}"; do
    if command -v "$tool" &> /dev/null; then
        echo "   OK: $tool"
    else
        echo "   FAIL: '$tool' not found — install it before building"
        FAILURES=$((FAILURES + 1))
    fi
done

echo ""

# ── 5. Yocto project structure ────────────────────────────────────────────────
echo ">> Checking project structure..."

REQUIRED_FILES=(
    "yocto/conf/local.conf.sample"
    "yocto/conf/bblayers.conf.sample"
    "yocto/meta-medtech/conf/layer.conf"
    "yocto/meta-medtech/recipes-image/core-image-medtech/core-image-medtech.bb"
)

for f in "${REQUIRED_FILES[@]}"; do
    if [ -f "$PROJECT_ROOT/$f" ]; then
        echo "   OK: $f"
    else
        echo "   FAIL: $f not found"
        FAILURES=$((FAILURES + 1))
    fi
done

echo ""

# ── 6. Environment defaults ───────────────────────────────────────────────────
echo ">> Checking environment variables..."

MACHINE="${MACHINE:-qemuarm64}"
DISTRO="${DISTRO:-poky}"
echo "   MACHINE = $MACHINE"
echo "   DISTRO  = $DISTRO"

echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
echo "========================================="
if [ "$FAILURES" -eq 0 ]; then
    echo "OK: All pre-flight checks passed — build can proceed."
    exit 0
else
    echo "FAIL: $FAILURES check(s) failed — fix the issues above before building."
    exit 1
fi
