echo "=== PYTHON RUNTIME SANITY CHECK (Non-Fatal) ==="
REQUIRED_PKGS=(python3 python3-paho-mqtt)
STDLIB_MODULES=(
    "argparse:python3-argparse|python3-core|python3-misc"
    "json:python3-json|python3-core|python3-misc"
    "logging:python3-logging|python3-core|python3-misc"
    "threading:python3-threading|python3-core|python3-misc"
    "typing:python3-typing|python3-core|python3-misc"
)

WARNINGS=0

if [ ! -f "$MANIFEST" ]; then
    echo "WARNING: Manifest not found: $MANIFEST"
    WARNINGS=$((WARNINGS+1))
else
    echo "-- Required Python runtime packages:"
    for pkg in "${REQUIRED_PKGS[@]}"; do
        if grep -Eq "^${pkg}\\b" "$MANIFEST"; then
            echo "  OK: $pkg"
        else
            echo "  WARNING: Missing $pkg"
            WARNINGS=$((WARNINGS+1))
        fi
    done

    echo "-- Stdlib module provider checks:"
    for entry in "${STDLIB_MODULES[@]}"; do
        module_name="${entry%%:*}"
        pattern="${entry#*:}"
        if grep -Eq "$pattern" "$MANIFEST"; then
            echo "  OK: $module_name provider present"
        else
            echo "  WARNING: $module_name provider not found"
            WARNINGS=$((WARNINGS+1))
        fi
    done

    echo "-- Regression guard (python3-modules):"
    if grep -Eq "^python3-modules\\b" "$MANIFEST"; then
        echo "  WARNING: Unexpected python3-modules found in image manifest"
        WARNINGS=$((WARNINGS+1))
    else
        echo "  OK: python3-modules not present"
    fi

    echo "-- Extra Python packages in manifest:"
    grep -E '^python3' "$MANIFEST" | grep -vE '^(python3|python3-paho-mqtt|python3-argparse|python3-json|python3-logging|python3-threading|python3-typing|python3-core|python3-misc|python3-modules)\\b' || echo "  (No extra python3-* packages)"
fi

if [ "$WARNINGS" -gt 0 ]; then
    echo "\nPYTHON RUNTIME SANITY CHECK: $WARNINGS warning(s) found. See above for details."
else
    echo "PYTHON RUNTIME SANITY CHECK: All required packages/providers present."
fi

#!/bin/bash
set -e

# Usage:
#   verify-image.sh [mode]
# Modes:
#   all (default): full image verification
#   python-sanity: only run Python runtime sanity check (for CI reuse)

MODE="${1:-all}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
YOCTO_ROOT="$PROJECT_ROOT/yocto"
BUILD_DIR="$YOCTO_ROOT/build"
DEPLOY_DIR="$BUILD_DIR/tmp/deploy/images/qemuarm64"
MANIFEST="$DEPLOY_DIR/core-image-medtech-qemuarm64.manifest"


run_python_sanity_check() {
    echo "=== PYTHON RUNTIME SANITY CHECK (Non-Fatal) ==="
    REQUIRED_PKGS=(python3 python3-paho-mqtt)
    STDLIB_MODULES=(
        "argparse:python3-argparse|python3-core|python3-misc"
        "json:python3-json|python3-core|python3-misc"
        "logging:python3-logging|python3-core|python3-misc"
        "threading:python3-threading|python3-core|python3-misc"
        "typing:python3-typing|python3-core|python3-misc"
    )
    WARNINGS=0
    if [ ! -f "$MANIFEST" ]; then
        echo "WARNING: Manifest not found: $MANIFEST"
        WARNINGS=$((WARNINGS+1))
    else
        echo "-- Required Python runtime packages:"
        for pkg in "${REQUIRED_PKGS[@]}"; do
            if grep -Eq "^${pkg}\\b" "$MANIFEST"; then
                echo "  OK: $pkg"
            else
                echo "  WARNING: Missing $pkg"
                WARNINGS=$((WARNINGS+1))
            fi
        done
        echo "-- Stdlib module provider checks:"
        for entry in "${STDLIB_MODULES[@]}"; do
            module_name="${entry%%:*}"
            pattern="${entry#*:}"
            if grep -Eq "$pattern" "$MANIFEST"; then
                echo "  OK: $module_name provider present"
            else
                echo "  WARNING: $module_name provider not found"
                WARNINGS=$((WARNINGS+1))
            fi
        done
        echo "-- Regression guard (python3-modules):"
        if grep -Eq "^python3-modules\\b" "$MANIFEST"; then
            echo "  WARNING: Unexpected python3-modules found in image manifest"
            WARNINGS=$((WARNINGS+1))
        else
            echo "  OK: python3-modules not present"
        fi
        echo "-- Extra Python packages in manifest:"
        grep -E '^python3' "$MANIFEST" | grep -vE '^(python3|python3-paho-mqtt|python3-argparse|python3-json|python3-logging|python3-threading|python3-typing|python3-core|python3-misc|python3-modules)\\b' || echo "  (No extra python3-* packages)"
    fi
    if [ "$WARNINGS" -gt 0 ]; then
        echo "\nPYTHON RUNTIME SANITY CHECK: $WARNINGS warning(s) found. See above for details."
    else
        echo "PYTHON RUNTIME SANITY CHECK: All required packages/providers present."
    fi
}

if [ "$MODE" = "python-sanity" ]; then
    run_python_sanity_check
    exit 0
fi

echo "=== MedTech Device OS Image Verification ==="
echo ""

# ...existing code for full image verification...
echo ""
echo "To boot in QEMU:"
echo "  cd $BUILD_DIR"
echo "  runqemu qemuarm64 core-image-medtech nographic"
echo ""
echo "Inside QEMU, sanity checks:"
echo "  systemctl status mosquitto medtech-vitals-publisher medtech-edge-analytics medtech-clinician-ui"
echo "  mosquitto_sub -t 'medtech/#' -v   # Should receive vitals + predictions"
echo "  journalctl -u medtech-vitals-publisher -n 50"
echo ""
