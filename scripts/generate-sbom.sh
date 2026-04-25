#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SBOM_DIR="$PROJECT_ROOT/sbom"

mkdir -p "$SBOM_DIR"

echo "=== Generating SBOM ==="

# TODO: Implement SBOM generation with Copilot

cat > "$SBOM_DIR/sbom.json" << 'SBOM'
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.4",
  "version": 1,
  "components": [
    {
      "type": "application",
      "name": "medtech-device-os",
      "version": "0.1.0",
      "description": "MedTech minimal Yocto device image"
    }
  ],
  "metadata": {
    "timestamp": "2024-04-25T00:00:00Z",
    "tools": [
      {
        "vendor": "Yocto",
        "name": "bitbake",
        "version": "2.0"
      }
    ]
  }
}
SBOM

echo "✅ SBOM generated: $SBOM_DIR/sbom.json"

