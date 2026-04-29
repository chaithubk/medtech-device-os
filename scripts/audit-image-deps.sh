#!/bin/bash

set -eo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
YOCTO_ROOT="$PROJECT_ROOT/yocto"
TARGET_IMAGE="${1:-core-image-medtech}"

if [[ "$(id -u)" -eq 0 ]]; then
    echo "ERROR: Run this as a non-root user (for example: builder)."
    echo "Example: su - builder -c 'cd /workspace && bash scripts/audit-image-deps.sh ${TARGET_IMAGE}'"
    exit 1
fi

if [[ ! -d "$YOCTO_ROOT/poky" ]]; then
    echo "ERROR: Poky not found at $YOCTO_ROOT/poky"
    exit 1
fi

cd "$YOCTO_ROOT"
source poky/oe-init-build-env build >/dev/null 2>&1

REPORT_DIR="$PWD/dependency-audit"
mkdir -p "$REPORT_DIR"

echo "=== Dependency Audit: $TARGET_IMAGE ==="
echo "Build dir   : $PWD"
echo "Report dir  : $REPORT_DIR"

echo ""
echo "[1/4] Generating dependency graph (dry-run)"
bitbake -g -n "$TARGET_IMAGE" >/dev/null
cp -f pn-buildlist "$REPORT_DIR/pn-buildlist.${TARGET_IMAGE}.txt"
cp -f task-depends.dot "$REPORT_DIR/task-depends.${TARGET_IMAGE}.dot"

echo ""
echo "[2/4] Capturing resolved image variables"
ENV_DUMP="$REPORT_DIR/bitbake-env.${TARGET_IMAGE}.txt"
bitbake -e "$TARGET_IMAGE" > "$ENV_DUMP"

grep -E '^CORE_IMAGE_BASE_INSTALL=|^IMAGE_FEATURES=|^IMAGE_INSTALL=|^DISTRO_FEATURES=' "$ENV_DUMP" \
    > "$REPORT_DIR/resolved-vars.${TARGET_IMAGE}.txt"

echo ""
echo "[3/4] Highlighting likely bloat drivers"
UNWANTED_REGEX='packagegroup-base-extended|ptest-runner|python3-pytest|python3-hypothesis|qtlanguageserver|packagegroup-base-wifi|packagegroup-base-bluetooth|packagegroup-base-nfc|packagegroup-base-3g'

grep -En "$UNWANTED_REGEX" "$REPORT_DIR/pn-buildlist.${TARGET_IMAGE}.txt" \
    > "$REPORT_DIR/bloat-hits.${TARGET_IMAGE}.txt" || true

awk '/^IMAGE_INSTALL=/{print}' "$REPORT_DIR/resolved-vars.${TARGET_IMAGE}.txt" \
    > "$REPORT_DIR/image-install.${TARGET_IMAGE}.txt"

echo ""
echo "[4/4] Service-level dependency extraction (meta-medtech)"
SERVICE_RDEPENDS_OUT="$REPORT_DIR/service-rdepends.${TARGET_IMAGE}.txt"
{
    echo "# Direct RDEPENDS from service recipes"
    grep -Rns "^RDEPENDS:\${PN}" "$PROJECT_ROOT/yocto/meta-medtech/recipes-services"/*.bb "$PROJECT_ROOT/yocto/meta-medtech/recipes-services"/*/*.bb 2>/dev/null || true
} > "$SERVICE_RDEPENDS_OUT"

echo ""
echo "=== Summary ==="
echo "Resolved vars: $REPORT_DIR/resolved-vars.${TARGET_IMAGE}.txt"
echo "Image install: $REPORT_DIR/image-install.${TARGET_IMAGE}.txt"
echo "Build closure: $REPORT_DIR/pn-buildlist.${TARGET_IMAGE}.txt"
echo "Task graph   : $REPORT_DIR/task-depends.${TARGET_IMAGE}.dot"
echo "Bloat hits   : $REPORT_DIR/bloat-hits.${TARGET_IMAGE}.txt"
echo "Service deps : $SERVICE_RDEPENDS_OUT"

if [[ -s "$REPORT_DIR/bloat-hits.${TARGET_IMAGE}.txt" ]]; then
    echo ""
    echo "Potential bloat candidates detected:"
    cat "$REPORT_DIR/bloat-hits.${TARGET_IMAGE}.txt"
else
    echo ""
    echo "No common bloat candidates matched the default pattern."
fi