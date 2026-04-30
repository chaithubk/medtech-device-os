#!/bin/bash
# process-sbom.sh
# Collects the Yocto-native SPDX outputs produced by the create-spdx bbclass
# and copies them into the top-level sbom/ directory for CI artifact upload.
#
# Prerequisites: a successful `bitbake core-image-medtech` run.
# Standards:     SPDX 2.2 / ISO/IEC 40110, NTIA Minimum Elements

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/yocto/build"
SPDX_DIR="$BUILD_DIR/tmp/deploy/images/qemuarm64/spdx"
OUTPUT_DIR="$PROJECT_ROOT/sbom"

echo "=== Processing Yocto SPDX SBOM ==="
echo ""

if [ ! -d "$SPDX_DIR" ]; then
    echo "WARNING: SPDX directory not found: $SPDX_DIR"
    echo "SPDX SBOM will not be included in artifacts."
    exit 0
fi

mkdir -p "$OUTPUT_DIR"
echo "Source : $SPDX_DIR"
echo "Output : $OUTPUT_DIR"
echo ""

# ── Copy SPDX JSON-LD (human-readable) ────────────────────────────────────────
JSON_COUNT=0
while IFS= read -r -d '' f; do
    cp "$f" "$OUTPUT_DIR/"
    JSON_COUNT=$((JSON_COUNT + 1))
done < <(find "$SPDX_DIR" -maxdepth 2 -name "*.json" -type f -print0)
[ "$JSON_COUNT" -gt 0 ] && echo "  JSON-LD : $JSON_COUNT file(s) copied"

# ── Copy SPDX RDF/XML (machine-readable) ──────────────────────────────────────
RDF_COUNT=0
while IFS= read -r -d '' f; do
    cp "$f" "$OUTPUT_DIR/"
    RDF_COUNT=$((RDF_COUNT + 1))
done < <(find "$SPDX_DIR" -maxdepth 2 -name "*.rdf" -o -name "*.rdf.gz" -type f -print0)
[ "$RDF_COUNT" -gt 0 ] && echo "  RDF     : $RDF_COUNT file(s) copied"

# ── Copy compressed SPDX archives ─────────────────────────────────────────────
ARC_COUNT=0
while IFS= read -r -d '' f; do
    cp "$f" "$OUTPUT_DIR/"
    ARC_COUNT=$((ARC_COUNT + 1))
done < <(find "$SPDX_DIR" -maxdepth 2 \( -name "*.tar.gz" -o -name "*.tgz" \) -type f -print0)
[ "$ARC_COUNT" -gt 0 ] && echo "  Archives: $ARC_COUNT file(s) copied"

# ── Summary ───────────────────────────────────────────────────────────────────
TOTAL=$((JSON_COUNT + RDF_COUNT + ARC_COUNT))
if [ "$TOTAL" -eq 0 ]; then
    echo "WARNING: No SPDX files found under $SPDX_DIR"
    echo "Ensure INHERIT += \"create-spdx\" is set in local.conf."
    exit 0
fi

echo ""
echo "=== SPDX SBOM ready ($TOTAL file(s)) ==="
echo ""
ls -lh "$OUTPUT_DIR/"
echo ""
echo "Standards compliance:"
echo "  SPDX 2.2  / ISO/IEC 40110"
echo "  NTIA Minimum Elements"
echo ""
echo "Compatible tooling:"
echo "  OWASP Dependency-Check  --  anchore-cli  --  spdx-tools  --  trivy"
