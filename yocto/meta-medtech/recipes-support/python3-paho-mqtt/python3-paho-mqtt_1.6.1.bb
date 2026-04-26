DESCRIPTION = "Python MQTT client library (paho-mqtt)"
SUMMARY = "Eclipse Paho MQTT Python client library"
HOMEPAGE = "https://github.com/eclipse/paho.mqtt.python"
LICENSE = "EPL-1.0 & EDL-1.0"
LIC_FILES_CHKSUM = "file://LICENSE.txt;md5=ca9a0b3b2f4d3a0e4b9d3e4a5a1c9a2e"

PYPI_PACKAGE = "paho-mqtt"

inherit pypi setuptools3

PV = "1.6.1"

SRC_URI[sha256sum] = "7f5d41a9f1eb6bb0b01ded36cd0bc3dd67eabf9bdb2e06ccad23a2c3c91f4be5"

RDEPENDS:${PN} = "python3-core python3-logging python3-threading"

BBCLASSEXTEND = "native nativesdk"
