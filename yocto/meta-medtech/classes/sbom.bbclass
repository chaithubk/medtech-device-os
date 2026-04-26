# sbom.bbclass
# Global SBOM (Software Bill of Materials) class for MedTech Device OS.
#
# Inherited globally via INHERIT += "sbom" in local.conf.
# Provides per-recipe SBOM fragment generation in CycloneDX JSON format.
# The image-level assembly is handled by medtech-image.bbclass.

SBOM_FORMAT ?= "json"
SBOM_DIR    ?= "${DEPLOY_DIR}/sbom"
SBOM_OUTPUT ?= "${SBOM_DIR}/sbom-${PN}-${PV}.json"

# Only generate fragments for real packages (skip native/cross tools and
# recipes that set INHIBIT_PACKAGE_STRIP / BPN overrides to meta-targets).
python do_sbom_fragment() {
    import json, os, datetime

    sbom_format = d.getVar("SBOM_FORMAT") or "json"
    if sbom_format.lower() != "json":
        bb.debug(1, "sbom.bbclass: SBOM_FORMAT is not 'json', skipping fragment for %s" % d.getVar("PN"))
        return

    pn      = d.getVar("PN") or "unknown"
    pv      = d.getVar("PV") or "unknown"
    pr      = d.getVar("PR") or "r0"
    license = d.getVar("LICENSE") or "UNKNOWN"
    desc    = d.getVar("DESCRIPTION") or d.getVar("SUMMARY") or ""
    homepage = d.getVar("HOMEPAGE") or ""

    sbom_dir = d.getVar("SBOM_DIR")
    if not sbom_dir:
        bb.warn("sbom.bbclass: SBOM_DIR not set, cannot write fragment for %s" % pn)
        return

    bb.utils.mkdirhier(sbom_dir)

    timestamp = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

    component = {
        "type": "library",
        "name": pn,
        "version": "%s-%s" % (pv, pr),
        "description": desc,
        "licenses": [{"license": {"id": license}}],
    }
    if homepage:
        component["externalReferences"] = [
            {"type": "website", "url": homepage}
        ]

    fragment = {
        "bomFormat": "CycloneDX",
        "specVersion": "1.4",
        "version": 1,
        "metadata": {
            "timestamp": timestamp,
            "component": {
                "type": "library",
                "name": pn,
                "version": "%s-%s" % (pv, pr),
            }
        },
        "components": [component],
    }

    out_path = d.getVar("SBOM_OUTPUT")
    try:
        with open(out_path, "w") as f:
            json.dump(fragment, f, indent=2)
        bb.debug(1, "sbom.bbclass: wrote fragment %s" % out_path)
    except Exception as e:
        bb.warn("sbom.bbclass: failed to write fragment for %s: %s" % (pn, str(e)))
}

# Run after packaging so PV/PR/LICENSE are fully resolved.
addtask do_sbom_fragment after do_package before do_build

# Mark as nostamp so it does not block incremental builds.
do_sbom_fragment[nostamp] = "1"
do_sbom_fragment[dirs]    = "${SBOM_DIR}"
