#!/bin/bash
#
# audit-image-deps.sh — Senior-Yocto-Architect-grade dependency audit.
#
# Produces actionable trim candidates by:
#   1. Resolving the full task/recipe closure for the target image.
#   2. Computing transitive bloat (recipes built but NOT in IMAGE_INSTALL).
#   3. Reverse-resolving WHY a candidate package was pulled in (RDEPENDS/RRECOMMENDS chain).
#   4. Ranking heaviest contributors using buildhistory size data when available.
#   5. Emitting BAD_RECOMMENDATIONS / IMAGE_INSTALL:remove suggestions ready to paste.
#
# Usage:  bash scripts/audit-image-deps.sh [image-name]   (default: core-image-medtech)
#         bash scripts/audit-image-deps.sh core-image-medtech --why bluez5

set -eo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
YOCTO_ROOT="$PROJECT_ROOT/yocto"
TARGET_IMAGE="${1:-core-image-medtech}"
WHY_PKG=""
if [[ "${2:-}" == "--why" && -n "${3:-}" ]]; then
    WHY_PKG="$3"
fi

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
# shellcheck disable=SC1091
source poky/oe-init-build-env build >/dev/null 2>&1

REPORT_DIR="$PWD/dependency-audit"
mkdir -p "$REPORT_DIR"

echo "=== Dependency Audit: $TARGET_IMAGE ==="
echo "Build dir   : $PWD"
echo "Report dir  : $REPORT_DIR"

# ---------------------------------------------------------------------------
# 1. Dependency graph (recipe-level + task-level)
# ---------------------------------------------------------------------------
echo ""
echo "[1/6] Generating dependency graph (dry-run)"
bitbake -g -n "$TARGET_IMAGE" >/dev/null
cp -f pn-buildlist           "$REPORT_DIR/pn-buildlist.${TARGET_IMAGE}.txt"
cp -f task-depends.dot       "$REPORT_DIR/task-depends.${TARGET_IMAGE}.dot"
[[ -f recipe-depends.dot ]] && cp -f recipe-depends.dot "$REPORT_DIR/recipe-depends.${TARGET_IMAGE}.dot"

CLOSURE_COUNT=$(wc -l < "$REPORT_DIR/pn-buildlist.${TARGET_IMAGE}.txt")
echo "    -> $CLOSURE_COUNT recipes in build closure"

# ---------------------------------------------------------------------------
# 2. Resolved image variables
# ---------------------------------------------------------------------------
echo ""
echo "[2/6] Capturing resolved image variables"
ENV_DUMP="$REPORT_DIR/bitbake-env.${TARGET_IMAGE}.txt"
bitbake -e "$TARGET_IMAGE" > "$ENV_DUMP"

grep -E '^(CORE_IMAGE_BASE_INSTALL|IMAGE_FEATURES|IMAGE_INSTALL|DISTRO_FEATURES|BAD_RECOMMENDATIONS|PACKAGE_EXCLUDE|BB_NUMBER_THREADS|PARALLEL_MAKE)=' "$ENV_DUMP" \
    > "$REPORT_DIR/resolved-vars.${TARGET_IMAGE}.txt"

# Extract IMAGE_INSTALL set as plain pkg list
awk -F'"' '/^IMAGE_INSTALL=/{print $2}' "$ENV_DUMP" \
    | tr -s ' \t' '\n' | sed '/^$/d' | sort -u \
    > "$REPORT_DIR/image-install.${TARGET_IMAGE}.list"
echo "    -> $(wc -l < "$REPORT_DIR/image-install.${TARGET_IMAGE}.list") packages directly requested in IMAGE_INSTALL"

# ---------------------------------------------------------------------------
# 3. Transitive bloat: in build closure but NOT directly requested
# ---------------------------------------------------------------------------
echo ""
echo "[3/6] Identifying transitive recipes (built but not in IMAGE_INSTALL)"
sort -u "$REPORT_DIR/pn-buildlist.${TARGET_IMAGE}.txt" \
    > "$REPORT_DIR/.closure.sorted"
# Filter native/cross out for clarity — they're build-time only.
TRANSITIVE="$REPORT_DIR/transitive-target.${TARGET_IMAGE}.txt"
comm -23 "$REPORT_DIR/.closure.sorted" "$REPORT_DIR/image-install.${TARGET_IMAGE}.list" \
    | grep -Ev '\-(native|cross|crosssdk|initial)$|^gcc-source-' \
    > "$TRANSITIVE" || true
echo "    -> $(wc -l < "$TRANSITIVE") transitive target recipes"

# ---------------------------------------------------------------------------
# 4. Highlight known-bloat patterns (curated for medtech profile)
# ---------------------------------------------------------------------------
echo ""
echo "[4/6] Scanning for known bloat patterns"
BLOAT_REGEX='^(packagegroup-base-extended|packagegroup-base-(wifi|bluetooth|nfc|3g|nfs)|ptest-runner|python3-pytest|python3-hypothesis|qtlanguageserver|bluez5|libical|gnome-desktop-testing|gnutls|libmicrohttpd|vala|python3-pygobject|python3-dbus|gobject-introspection|gtk-doc|bash-completion|kbd|btrfs-tools|mdadm|socat|virglrenderer|mesa|libepoxy|qtsvg|qtwayland|qttools|qtwebengine|qtmultimedia)(\b|$)'

BLOAT_OUT="$REPORT_DIR/bloat-hits.${TARGET_IMAGE}.txt"
{
    echo "# Known-bloat hits (recipe name matches a curated pattern)"
    echo "# Format: <recipe>     <direct|transitive>"
    while read -r pkg; do
        if [[ "$pkg" =~ $BLOAT_REGEX ]]; then
            if grep -qx "$pkg" "$REPORT_DIR/image-install.${TARGET_IMAGE}.list"; then
                printf '%-40s direct\n'    "$pkg"
            else
                printf '%-40s transitive\n' "$pkg"
            fi
        fi
    done < "$REPORT_DIR/.closure.sorted"
} > "$BLOAT_OUT"

# ---------------------------------------------------------------------------
# 5. Reverse-dependency lookup ("why is X being built?")
# ---------------------------------------------------------------------------
why_lookup() {
    local pkg="$1"
    local depfile="$REPORT_DIR/task-depends.${TARGET_IMAGE}.dot"
    local out="$REPORT_DIR/why-${pkg}.${TARGET_IMAGE}.txt"
    {
        echo "# Reverse dependency chain for: $pkg"
        echo "# (extracted from $depfile)"
        echo ""
        # Each edge in DOT is:  "consumer.task" -> "producer.task"
        # We want consumers of the target package — i.e. left side of edges where right side mentions $pkg.
        grep -F "\"${pkg}\." "$depfile" \
            | awk -F'"' '$4 ~ /^'"$pkg"'\./ {print $2}' \
            | sed 's/\.[a-zA-Z_0-9]*$//' \
            | sort -u
    } > "$out"
    local n
    n=$(grep -cv '^#' "$out" 2>/dev/null || echo 0)
    echo "    -> $pkg : $n direct consumers logged in $(basename "$out")"
}

echo ""
echo "[5/6] Reverse-dependency lookup for top bloat candidates"
DEFAULT_WHY=(bluez5 libical gnutls libmicrohttpd vala python3-pygobject python3-dbus gobject-introspection bash-completion ptest-runner mesa virglrenderer qtsvg)
if [[ -n "$WHY_PKG" ]]; then
    DEFAULT_WHY=("$WHY_PKG")
fi
for p in "${DEFAULT_WHY[@]}"; do
    if grep -qx "$p" "$REPORT_DIR/.closure.sorted"; then
        why_lookup "$p"
    fi
done

# ---------------------------------------------------------------------------
# 6. Buildhistory-driven size ranking (best signal we have for "fat" packages)
# ---------------------------------------------------------------------------
echo ""
echo "[6/6] Buildhistory size ranking"
BH_DIR="$PWD/buildhistory/packages"
SIZE_OUT="$REPORT_DIR/package-sizes.${TARGET_IMAGE}.txt"
if [[ -d "$BH_DIR" ]]; then
    {
        echo "# Top 50 installed packages by size (bytes) — from buildhistory"
        find "$BH_DIR" -name latest -path '*/packages/*' 2>/dev/null \
            | while read -r f; do
                pn=$(basename "$(dirname "$f")")
                size=$(awk -F'= ' '/^PKGSIZE/{print $2; exit}' "$f" 2>/dev/null)
                [[ -n "$size" ]] && printf '%12s  %s\n' "$size" "$pn"
              done \
            | sort -rn | head -50
    } > "$SIZE_OUT"
    echo "    -> top-50 installed sizes -> $(basename "$SIZE_OUT")"
else
    echo "    -> buildhistory not enabled; enable with INHERIT += \"buildhistory\" in local.conf for size ranking."
    echo "# buildhistory disabled — re-run after a successful build with INHERIT += buildhistory" > "$SIZE_OUT"
fi

# ---------------------------------------------------------------------------
# Service-level RDEPENDS audit (meta-medtech)
# ---------------------------------------------------------------------------
SERVICE_RDEPENDS_OUT="$REPORT_DIR/service-rdepends.${TARGET_IMAGE}.txt"
{
    echo "# Direct RDEPENDS / DEPENDS from meta-medtech service recipes"
    grep -RnsE '^(RDEPENDS:\$\{PN\}|DEPENDS)' \
        "$PROJECT_ROOT/yocto/meta-medtech/recipes-services" \
        "$PROJECT_ROOT/yocto/meta-medtech/recipes-support" \
        "$PROJECT_ROOT/yocto/meta-medtech/recipes-core" 2>/dev/null || true
} > "$SERVICE_RDEPENDS_OUT"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=========================================================="
echo "Audit complete — reports in: $REPORT_DIR"
echo "=========================================================="
echo "  Build closure (recipes)  : $CLOSURE_COUNT"
echo "  Direct IMAGE_INSTALL pkgs: $(wc -l < "$REPORT_DIR/image-install.${TARGET_IMAGE}.list")"
echo "  Transitive target recipes: $(wc -l < "$TRANSITIVE")"
echo ""
echo "Curated bloat hits:"
sed 's/^/  /' "$BLOAT_OUT"
echo ""
echo "To inspect why a package is built:"
echo "  bash scripts/audit-image-deps.sh $TARGET_IMAGE --why <pkgname>"
echo ""
echo "Suggested follow-ups:"
echo "  - Add transitive-only bloat hits to BAD_RECOMMENDATIONS (in local.conf or image bbclass)"
echo "  - Check why-<pkg>.txt files to find the recipe pulling each candidate"
echo "  - Re-run build with: INHERIT += \"buildhistory\" to populate $SIZE_OUT"
