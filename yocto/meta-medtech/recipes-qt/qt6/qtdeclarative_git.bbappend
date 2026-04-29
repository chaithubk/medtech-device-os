# Trim build-time Qt tooling not required for clinician-ui runtime.
# qtlanguageserver is a development-time component and increases CI build load.
DEPENDS:remove = "qtlanguageserver"
