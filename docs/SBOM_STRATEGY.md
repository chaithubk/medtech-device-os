# SBOM Strategy — MedTech Device OS

## Overview

MedTech Device OS generates a **Software Bill of Materials (SBOM)** using
Yocto's native `create-spdx` class.  Every package built by BitBake receives
an SPDX 2.2 document automatically; the image-level document assembles them
into a single authoritative manifest.

## Standards Compliance

| Standard | Status |
|---|---|
| SPDX 2.2 / ISO/IEC 40110 | ✅ |
| NTIA Minimum Elements | ✅ |
| OWASP Dependency-Check compatible | ✅ |
| Anchore / Trivy compatible | ✅ |

## How It Works

### 1. Build time

`INHERIT += "create-spdx"` in `yocto/conf/local.conf` activates the class
globally.  During `bitbake core-image-medtech`, Yocto:

1. Generates an SPDX document per recipe (package name, version, hash, license,
   source references).
2. Assembles a complete image-level SPDX document after `do_rootfs`.
3. Writes everything to `tmp/deploy/images/qemuarm64/spdx/`.

### 2. Collection

`scripts/process-sbom.sh` copies the SPDX outputs into `sbom/` for CI
artifact upload.  Run it after a successful build:

```bash
bash scripts/process-sbom.sh
```

### 3. Output formats

| File pattern | Format | Purpose |
|---|---|---|
| `*.spdx.json` | JSON-LD | Human-readable review |
| `*.spdx.rdf.gz` | RDF/XML (gzip) | Machine-readable tooling |
| `*.tar.gz` | Archive | Complete per-package SPDX bundle |

### 4. What each document contains

- Component name, version, and package hash
- License expression (SPDX identifier)
- Source code references (`SPDX_INCLUDE_SOURCES = "1"`)
- Supplier and author metadata
- DESCRIBES / CONTAINS relationships between image and packages

## Configuration (`yocto/conf/local.conf`)

```bitbake
INHERIT += "create-spdx"
SPDX_PRETTY              = "1"    # Indented JSON
SPDX_ARCHIVE_COMPRESS    = "gz"   # Compress per-package archives
SPDX_INCLUDE_SOURCES     = "1"    # Include source refs
SPDX_DEPLOY_DIR          = "${DEPLOY_DIR_IMAGE}/spdx"
```

## CI/CD Integration

Both GitHub Actions workflows (`device-build.yml`, `device-build-smart.yml`):

1. Run `bitbake core-image-medtech` — SPDX generation is automatic.
2. Run `bash scripts/process-sbom.sh` — collects SPDX into `sbom/`.
3. Upload `sbom/` as a build artifact (retained 30 days).

## Tooling

```bash
# Validate with spdx-tools
pip install spdx-tools
pyspdxtools validate sbom/core-image-medtech-qemuarm64.spdx.json

# Scan with Trivy
trivy sbom sbom/core-image-medtech-qemuarm64.spdx.json

# Scan with OWASP Dependency-Check
dependency-check --project "MedTech Device OS" \
  --scan sbom/core-image-medtech-qemuarm64.spdx.json
```

## Architecture Decision

| Approach | Decision |
|---|---|
| Custom CycloneDX heredoc in `.bbclass` | ❌ Removed — BitBake parser rejects bash heredoc delimiters |
| Custom `sbom.bbclass` per recipe | ❌ Removed — reinvents what Poky already provides |
| **Yocto native `create-spdx`** | ✅ Adopted — maintained by Yocto project, ISO/IEC compliant |

## Future Work

- [ ] Automated CVE scan in CI using Trivy against SPDX output
- [ ] License compliance gate (block build on GPL-3.0 in closed firmware)
- [ ] SBOM signing / attestation (sigstore/cosign)
- [ ] CycloneDX conversion via `cyclonedx-py` for tools that prefer that format
- [ ] Cloud SBOM repository ingestion
