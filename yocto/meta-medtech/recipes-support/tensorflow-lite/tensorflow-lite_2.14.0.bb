DESCRIPTION = "TensorFlow Lite runtime for embedded ML inference"
SUMMARY = "TensorFlow Lite provides ML inferencing on resource-constrained devices"
HOMEPAGE = "https://www.tensorflow.org/lite"
LICENSE = "Apache-2.0"
# LICENSE lives at the root of the git checkout (${WORKDIR}/git/LICENSE)
LIC_FILES_CHKSUM = "file://${WORKDIR}/git/LICENSE;md5=4158a261ca7f2525513e31ba9c50ae98"

PV = "2.14.0"

# Permanent fix: pin to exact commit SHA for tag v2.14.0.
# GitHub auto-generated tarballs regenerate over time (non-stable sha256).
# A git SRCREV is immutable — it will never drift.
SRCREV = "4dacf3f368eb7965e9b5c3bbdd5193986081c3b2"

inherit cmake

SRC_URI = "git://github.com/tensorflow/tensorflow.git;protocol=https;branch=v2.14;nobranch=1"

S = "${WORKDIR}/git/tensorflow/lite"

DEPENDS = " \
    flatbuffers \
    abseil-cpp \
    zlib \
"

RDEPENDS:${PN} = "zlib"

EXTRA_OECMAKE = " \
    -DTFLITE_ENABLE_XNNPACK=OFF \
    -DTFLITE_ENABLE_GPU=OFF \
    -DTFLITE_ENABLE_NNAPI=OFF \
    -DTFLITE_ENABLE_RUY=ON \
    -DOVERRIDABLE_FETCH_CONTENT_LICENSE_CHECK=OFF \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_BUILD_TYPE=Release \
"

# Build only the core tflite library, not the full tools suite
EXTRA_OECMAKE += "-DTFLITE_BUILD_SHARED_LIB=ON"

do_install() {
    install -d ${D}${libdir}
    install -d ${D}${includedir}/tensorflow/lite

    # Install shared library
    if [ -f ${B}/libtensorflow-lite.so ]; then
        install -m 0755 ${B}/libtensorflow-lite.so ${D}${libdir}/libtensorflow-lite.so.${PV}
        ln -sf libtensorflow-lite.so.${PV} ${D}${libdir}/libtensorflow-lite.so
    else
        bbfatal "Expected shared library not found: ${B}/libtensorflow-lite.so. Check EXTRA_OECMAKE flags."
    fi

    # Install headers from git checkout layout
    find ${WORKDIR}/git/tensorflow/lite -name "*.h" | while read header; do
        relpath="${header#${WORKDIR}/git/}"
        destdir="${D}${includedir}/$(dirname ${relpath})"
        install -d "${destdir}"
        install -m 0644 "${header}" "${destdir}/"
    done
}

FILES:${PN} = "${libdir}/libtensorflow-lite.so*"
FILES:${PN}-dev = "${includedir}/tensorflow"

# INSANE_SKIP: dev-so is needed because the .so symlink must ship in the
# runtime package so that Python/C++ code can dlopen libtensorflow-lite.so
# without requiring the -dev package at runtime.
INSANE_SKIP:${PN} = "dev-so"
