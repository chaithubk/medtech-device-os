DESCRIPTION = "TensorFlow Lite runtime for embedded ML inference"
SUMMARY = "TensorFlow Lite provides ML inferencing on resource-constrained devices"
HOMEPAGE = "https://www.tensorflow.org/lite"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://LICENSE;md5=01e86893010a1b87e69a213faa753ebd"

PV = "2.14.0"

inherit cmake

SRC_URI = "https://github.com/tensorflow/tensorflow/archive/refs/tags/v${PV}.tar.gz;downloadfilename=tensorflow-${PV}.tar.gz"
SRC_URI[sha256sum] = "3f85af774ee5e4a6dcc36d19f0bb3b1f32af8b96b00462acd5e2e12be8d1e4db"

S = "${WORKDIR}/tensorflow-${PV}/tensorflow/lite"

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

    # Install headers
    find ${WORKDIR}/tensorflow-${PV}/tensorflow/lite -name "*.h" | while read header; do
        relpath="${header#${WORKDIR}/tensorflow-${PV}/}"
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
