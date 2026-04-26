# medtech-image.bbclass
# Custom Yocto class for MedTech image post-processing:
#   - Stamps image version and build metadata into /etc/medtech-release
# SBOM generation is handled by Yocto's native create-spdx class (see local.conf).

MEDTECH_IMAGE_VERSION ?= "1.0.0"
MEDTECH_IMAGE_NAME ?= "core-image-medtech"

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


