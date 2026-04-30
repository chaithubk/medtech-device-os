DESCRIPTION = "TensorFlow Lite runtime for embedded ML inference"
SUMMARY = "TensorFlow Lite provides ML inferencing on resource-constrained devices"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://LICENSE;md5=4158a261ca7f2525513e31ba9c50ae98"

PV = "2.14.0"
MAJOR = "2"
SRCREV = "4dacf3f368eb7965e9b5c3bbdd5193986081c3b2"

SRC_URI = "git://github.com/tensorflow/tensorflow.git;protocol=https;branch=v2.14;nobranch=1"
S = "${WORKDIR}/git"
OECMAKE_SOURCEPATH = "${S}/tensorflow/lite"

inherit cmake python3native

DEPENDS = " \
    zlib \
    flatbuffers \
    flatbuffers-native \
    abseil-cpp \
    python3-numpy-native \
    ca-certificates-native \
    ninja-native \
"

# RUY is used for ARM stability. XNNPACK is disabled to prevent QEMU illegal instructions.
EXTRA_OECMAKE = " \
    -DTFLITE_ENABLE_RUY=ON \
    -DTFLITE_ENABLE_XNNPACK=OFF \
    -DTFLITE_ENABLE_GPU=OFF \
    -DTFLITE_ENABLE_NNAPI=OFF \
    -DBUILD_SHARED_LIBS=ON \
    -DTFLITE_BUILD_SHARED_LIB=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DFETCHCONTENT_FULLY_DISCONNECTED=OFF \
    -DTFLITE_VERSION_MAJOR=${MAJOR} \
"

do_configure[network] = "1"

do_configure:prepend() {
    # Fix the Fortran compiler error [User History]
    unset FC
    # Address SSL certificate failures for internal Git clones [360, User History]
    export GIT_SSL_NO_VERIFY=1
    export GIT_SSL_CAINFO="${STAGING_ETCDIR_NATIVE}/ssl/certs/ca-certificates.crt"
    
    # Apply the license check patch
    sed -i 's/^set(OVERRIDABLE_FETCH_CONTENT_LICENSE_CHECK ON)/set(OVERRIDABLE_FETCH_CONTENT_LICENSE_CHECK OFF)/' ${OECMAKE_SOURCEPATH}/CMakeLists.txt
}

do_install() {
    install -d ${D}${libdir}
    
    # 1. Install the primary TFLite library
    if [ -f ${B}/libtensorflow-lite.so ]; then
        install -m 0755 ${B}/libtensorflow-lite.so ${D}${libdir}/libtensorflow-lite.so.${PV}
        ln -sf libtensorflow-lite.so.${PV} ${D}${libdir}/libtensorflow-lite.so.${MAJOR}
        ln -sf libtensorflow-lite.so.${PV} ${D}${libdir}/libtensorflow-lite.so
    fi

    # 2. THE FIX FOR QA ISSUE: Install transitive shared libraries built by CMake.
    # We search the build tree for all .so files (farmhash, fft2d, cpuinfo, etc.)
    # and install them so they are available at runtime [1, 3].
    find ${B} -name "*.so*" -not -name "libtensorflow-lite.so*" -type f -exec install -m 0755 {} ${D}${libdir} \;

    # 3. Install headers preserving directory structure [User History]
    install -d ${D}${includedir}/tensorflow/lite
    cd ${S}/tensorflow/lite
    cp --parents $(find . -name "*.h") ${D}${includedir}/tensorflow/lite
}

# Ensure all installed shared libraries are included in the package
FILES:${PN} += "${libdir}/*.so*"
FILES:${PN}-dev = "${includedir}/tensorflow"

# Required because we ship .so symlinks in the runtime package for 
# Python/C++ dlopen support [User History].
INSANE_SKIP:${PN} = "dev-so"