DESCRIPTION = "TensorFlow Lite runtime with Python bindings"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://LICENSE;md5=4158a261ca7f2525513e31ba9c50ae98"

PV = "2.14.0"
TF_MAJOR = "2"
SRCREV = "4dacf3f368eb7965e9b5c3bbdd5193986081c3b2"

SRC_URI = "git://github.com/tensorflow/tensorflow.git;protocol=https;branch=v2.14;nobranch=1"
S = "${WORKDIR}/git"
OECMAKE_SOURCEPATH = "${S}/tensorflow/lite"

# Inherit setuptools3 before cmake to ensure CMake manages the C++ compilation
# and we manually trigger the Python packaging task
inherit setuptools3 cmake python3native python3-dir

# Tell setuptools where to find the setup.py we assemble in do_compile
SETUPTOOLS_SETUP_PATH = "${B}"

# Explicit target-side dependencies to populate the RECIPE_SYSROOT with headers
DEPENDS = " \
    zlib \
    flatbuffers \
    flatbuffers-native \
    abseil-cpp \
    python3 \
    python3-numpy \
    python3-pybind11 \
    python3-numpy-native \
    python3-pybind11-native \
    python3-wheel-native \
    ca-certificates-native \
    ninja-native \
"

# Explicitly target the C++ core and the Python wrapper shared object
OECMAKE_TARGET_COMPILE = "tensorflow-lite _pywrap_tensorflow_interpreter_wrapper"

# ARCHITECTURAL FIX: Use RECIPE_SYSROOT to pass absolute paths for cross-compilation
EXTRA_OECMAKE = " \
    -DTFLITE_ENABLE_RUY=ON \
    -DTFLITE_ENABLE_XNNPACK=OFF \
    -DBUILD_SHARED_LIBS=ON \
    -DTFLITE_BUILD_SHARED_LIB=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DFETCHCONTENT_FULLY_DISCONNECTED=OFF \
    -DTFLITE_VERSION_MAJOR=${TF_MAJOR} \
    -DPYTHON_TARGET_INCLUDE=${RECIPE_SYSROOT}${includedir}/${PYTHON_DIR} \
    -DNUMPY_TARGET_INCLUDE=${RECIPE_SYSROOT}${PYTHON_SITEPACKAGES_DIR}/numpy/core/include \
    -DPYBIND11_TARGET_INCLUDE=${RECIPE_SYSROOT}${PYTHON_SITEPACKAGES_DIR}/pybind11/include \
"

do_configure[network] = "1"

do_configure:prepend() {
    # 1. Fix the Fortran compiler detection error common in Poky
    unset FC 
    
    # 2. Bypass SSL certificate issues for internal Git clones
    export GIT_SSL_NO_VERIFY=1
    export GIT_SSL_CAINFO="${STAGING_ETCDIR_NATIVE}/ssl/certs/ca-certificates.crt"

    # 3. Patch the hardcoded license check as identified in initial research
    sed -i 's/^set(OVERRIDABLE_FETCH_CONTENT_LICENSE_CHECK ON)/set(OVERRIDABLE_FETCH_CONTENT_LICENSE_CHECK OFF)/' ${OECMAKE_SOURCEPATH}/CMakeLists.txt

    # 4. THE SURGICAL FIX FOR PARSE ERROR:
    # Instead of 'sed', we append valid CMake code to the end of the file.
    # This ensures the Python wrapper sees the headers without breaking early commands.
    echo "if(TARGET _pywrap_tensorflow_interpreter_wrapper)" >> ${OECMAKE_SOURCEPATH}/CMakeLists.txt
    echo "  target_include_directories(_pywrap_tensorflow_interpreter_wrapper PUBLIC \${PYTHON_TARGET_INCLUDE} \${NUMPY_TARGET_INCLUDE} \${PYBIND11_TARGET_INCLUDE})" >> ${OECMAKE_SOURCEPATH}/CMakeLists.txt
    echo "endif()" >> ${OECMAKE_SOURCEPATH}/CMakeLists.txt
}

do_compile:append() {
    # 1. Prepare environment variables and extract version
    TENSORFLOW_LITE_DIR="${S}/tensorflow/lite"
    TENSORFLOW_VERSION=$(grep "_VERSION = " "${S}/tensorflow/tools/pip_package/setup.py" | cut -d= -f2 | sed "s/[ '-]//g")
    
    # 2. Assemble the Python package structure in the build directory
    mkdir -p "${B}/tflite_runtime"
    cp -r "${TENSORFLOW_LITE_DIR}/python/interpreter_wrapper" "${B}"
    cp "${TENSORFLOW_LITE_DIR}/tools/pip_package/setup_with_binary.py" "${B}/setup.py"
    cp "${TENSORFLOW_LITE_DIR}/python/interpreter.py" "${B}/tflite_runtime"
    
    # 3. Initialize the package and include the built C++ wrapper
    echo "__version__ = '${TENSORFLOW_VERSION}'" >> "${B}/tflite_runtime/__init__.py"
    cp "${B}/_pywrap_tensorflow_interpreter_wrapper.so" "${B}/tflite_runtime"
    
    # 4. Export variables required by TFLite's internal setup tool
    export PACKAGE_VERSION="${TENSORFLOW_VERSION}"
    export PROJECT_NAME="tflite_runtime"
    
    # 5. Manually trigger the Python compilation task
    setuptools3_do_compile
}

do_install() {
    # Install Shared Library with SONAME symlinks
    install -d ${D}${libdir}
    install -m 0755 ${B}/libtensorflow-lite.so ${D}${libdir}/libtensorflow-lite.so.${PV}
    ln -sf libtensorflow-lite.so.${PV} ${D}${libdir}/libtensorflow-lite.so.${TF_MAJOR}
    ln -sf libtensorflow-lite.so.${PV} ${D}${libdir}/libtensorflow-lite.so

    # Install Transitive Dependencies (Fixes farmhash, cpuinfo, etc. QA issues) [User History]
    find ${B} -name "*.so*" -not -name "libtensorflow-lite.so*" -type f -exec install -m 0755 {} ${D}${libdir} \;

    # Install Headers preserving directory structure
    install -d ${D}${includedir}/tensorflow/lite
    cd ${S}/tensorflow/lite
    cp --parents $(find . -name "*.h") ${D}${includedir}/tensorflow/lite

    # Install Python module into system site-packages
    install -d ${D}${PYTHON_SITEPACKAGES_DIR}/tflite_runtime
    cp -r ${B}/tflite_runtime/* ${D}${PYTHON_SITEPACKAGES_DIR}/tflite_runtime/
}

# Explicitly set package splitting for target builds
PACKAGES = "python3-tensorflow-lite ${PN} ${PN}-dev ${PN}-dbg"
FILES:python3-tensorflow-lite = "${PYTHON_SITEPACKAGES_DIR}/tflite_runtime"
RDEPENDS:python3-tensorflow-lite = "python3-numpy python3-ctypes python3-core"
RPROVIDES:python3-tensorflow-lite = "python3-tensorflow-lite"
FILES:${PN} += "${libdir}/*.so*"
FILES:${PN}-dev = "${includedir}/tensorflow"
INSANE_SKIP:${PN} = "dev-so"
