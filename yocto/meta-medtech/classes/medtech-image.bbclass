# medtech-image.bbclass
# Custom Yocto class for MedTech image post-processing:
#   - Stamps image version into /etc/medtech-release
#   - Generates a static CycloneDX SBOM catalog for the image
#   - Records build metadata for traceability

MEDTECH_IMAGE_VERSION ?= "1.0.0"
MEDTECH_IMAGE_NAME ?= "core-image-medtech"
MEDTECH_SBOM_DIR ?= "${DEPLOY_DIR}/sbom"

# Stamp release info into the rootfs
IMAGE_PREPROCESS_COMMAND:append = " medtech_stamp_release; "

medtech_stamp_release() {
    install -d ${IMAGE_ROOTFS}/etc
    cat > ${IMAGE_ROOTFS}/etc/medtech-release << EOF
MEDTECH_IMAGE_NAME="${MEDTECH_IMAGE_NAME}"
MEDTECH_IMAGE_VERSION="${MEDTECH_IMAGE_VERSION}"
MEDTECH_BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
MEDTECH_MACHINE="${MACHINE}"
MEDTECH_DISTRO="${DISTRO}"
EOF
}

# Generate a basic CycloneDX-compatible SBOM fragment after rootfs creation
ROOTFS_POSTPROCESS_COMMAND:append = " medtech_generate_sbom; "

medtech_generate_sbom() {
    SBOM_FILE="${MEDTECH_SBOM_DIR}/sbom-${MEDTECH_IMAGE_NAME}.json"
    install -d "${MEDTECH_SBOM_DIR}"

    TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    cat > "${SBOM_FILE}" << SBOMEOF
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
      "name": "${MEDTECH_IMAGE_NAME}",
      "version": "${MEDTECH_IMAGE_VERSION}",
      "description": "MedTech Stage 1 QEMU Image"
    }
  },
  "components": [
    {
      "type": "application",
      "name": "medtech-vitals-publisher",
      "version": "1.0",
      "description": "MQTT vital signs publisher",
      "scope": "required",
      "purl": "pkg:github/chaithubk/medtech-vitals-publisher@1.0"
    },
    {
      "type": "application",
      "name": "medtech-edge-analytics",
      "version": "1.0",
      "description": "Sepsis detection with TensorFlow Lite",
      "scope": "required",
      "purl": "pkg:github/chaithubk/medtech-edge-analytics@1.0"
    },
    {
      "type": "application",
      "name": "medtech-clinician-ui",
      "version": "1.0",
      "description": "Qt6-based clinical dashboard",
      "scope": "required",
      "purl": "pkg:github/chaithubk/medtech-clinician-ui@1.0"
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
      "version": "2.14.0",
      "description": "TensorFlow Lite runtime",
      "scope": "required"
    },
    {
      "type": "library",
      "name": "python3-paho-mqtt",
      "version": "1.6.1",
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
SBOMEOF
}
