#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SBOM_DIR="$PROJECT_ROOT/sbom"

mkdir -p "$SBOM_DIR"

echo "=== Generating MedTech CycloneDX SBOM ==="

# Extract versions from recipe files if available
VITALS_VERSION="1.0.0"
ANALYTICS_VERSION="1.0.0"
UI_VERSION="1.0.0"
TFLITE_VERSION="2.14.0"
PAHO_VERSION="1.6.1"

RECIPES_DIR="$PROJECT_ROOT/yocto/meta-medtech"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
if [ -d "$RECIPES_DIR" ]; then
    vp=$(find "$RECIPES_DIR" -name "vitals-publisher_*.bb" 2>/dev/null | head -1)
    ea=$(find "$RECIPES_DIR" -name "edge-analytics_*.bb" 2>/dev/null | head -1)
    cu=$(find "$RECIPES_DIR" -name "clinician-ui_*.bb" 2>/dev/null | head -1)
    tf=$(find "$RECIPES_DIR" -name "tensorflow-lite_*.bb" 2>/dev/null | head -1)
    pm=$(find "$RECIPES_DIR" -name "python3-paho-mqtt_*.bb" 2>/dev/null | head -1)

    [ -n "$vp" ] && VITALS_VERSION="$(basename "$vp" .bb | cut -d_ -f2)"
    [ -n "$ea" ] && ANALYTICS_VERSION="$(basename "$ea" .bb | cut -d_ -f2)"
    [ -n "$cu" ] && UI_VERSION="$(basename "$cu" .bb | cut -d_ -f2)"
    [ -n "$tf" ] && TFLITE_VERSION="$(basename "$tf" .bb | cut -d_ -f2)"
    [ -n "$pm" ] && PAHO_VERSION="$(basename "$pm" .bb | cut -d_ -f2)"
fi

cat > "$SBOM_DIR/sbom.json" << SBOM
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.4",
  "version": 1,
  "metadata": {
    "timestamp": "${TIMESTAMP}",
    "tools": [
      {
        "vendor": "Yocto",
        "name": "bitbake",
        "version": "2.0"
      }
    ],
    "component": {
      "type": "application",
      "name": "core-image-medtech",
      "version": "1.0.0",
      "description": "MedTech Stage 1 QEMU Image"
    }
  },
  "components": [
    {
      "type": "application",
      "name": "medtech-vitals-publisher",
      "version": "${VITALS_VERSION}",
      "description": "MQTT vital signs publisher",
      "scope": "required",
      "purl": "pkg:github/chaithubk/medtech-vitals-publisher@${VITALS_VERSION}"
    },
    {
      "type": "application",
      "name": "medtech-edge-analytics",
      "version": "${ANALYTICS_VERSION}",
      "description": "Sepsis detection with TensorFlow Lite",
      "scope": "required",
      "purl": "pkg:github/chaithubk/medtech-edge-analytics@${ANALYTICS_VERSION}"
    },
    {
      "type": "application",
      "name": "medtech-clinician-ui",
      "version": "${UI_VERSION}",
      "description": "Qt6-based clinical dashboard",
      "scope": "required",
      "purl": "pkg:github/chaithubk/medtech-clinician-ui@${UI_VERSION}"
    },
    {
      "type": "library",
      "name": "mosquitto",
      "version": "2.0.x",
      "description": "MQTT message broker",
      "scope": "required"
    },
    {
      "type": "library",
      "name": "tensorflow-lite",
      "version": "${TFLITE_VERSION}",
      "description": "TensorFlow Lite runtime",
      "scope": "required"
    },
    {
      "type": "library",
      "name": "python3-paho-mqtt",
      "version": "${PAHO_VERSION}",
      "description": "Python MQTT client",
      "scope": "required"
    },
    {
      "type": "library",
      "name": "qtbase",
      "version": "6.x.x",
      "description": "Qt6 base libraries",
      "scope": "required"
    }
  ],
  "services": [
    {
      "name": "mosquitto",
      "endpoint": "mqtt://localhost:1883",
      "status": "required"
    },
    {
      "name": "medtech-vitals-publisher",
      "depends": ["mosquitto"],
      "endpoint": "mqtt://localhost/medtech/vitals/latest",
      "status": "required"
    },
    {
      "name": "medtech-edge-analytics",
      "depends": ["mosquitto", "medtech-vitals-publisher"],
      "endpoint": "mqtt://localhost/medtech/predictions/sepsis",
      "status": "required"
    },
    {
      "name": "medtech-clinician-ui",
      "depends": ["medtech-edge-analytics"],
      "endpoint": "Qt6 application",
      "status": "required"
    }
  ]
}
SBOM

echo "✅ SBOM generated: $SBOM_DIR/sbom.json"
echo "   Components: medtech-vitals-publisher, medtech-edge-analytics, medtech-clinician-ui"
echo "   Libraries:  mosquitto, tensorflow-lite, python3-paho-mqtt, qtbase"

