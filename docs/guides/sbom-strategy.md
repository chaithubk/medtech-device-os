# SBOM Strategy - MedTech Device OS

## Overview

MedTech Device OS supports SPDX SBOM generation using Yocto's native
`create-spdx` class, but it is disabled by default to keep CI runs faster.

You can enable it when needed (for release/compliance/manual runs) through a
single toggle.

## Default behavior

- Default: SPDX generation is OFF.
- Toggle variable in Yocto config: `MEDTECH_ENABLE_SPDX`.
- Workflow input for manual runs: `spdx_enabled`.

When OFF, no `do_create_spdx` tasks are added.
When ON, Yocto runs SPDX generation tasks and CI collects the outputs.

## Configuration

`yocto/conf/local.conf.sample` contains:

```bitbake
MEDTECH_ENABLE_SPDX ?= "0"
INHERIT:append = "${@' create-spdx' if (d.getVar('MEDTECH_ENABLE_SPDX') or '').strip().lower() in ('1', 'true', 'yes', 'on') else ''}"

SPDX_PRETTY = "1"
SPDX_ARCHIVE_COMPRESS = "gz"
SPDX_INCLUDE_SOURCES = "0"
SPDX_DEPLOY_DIR = "${DEPLOY_DIR_IMAGE}/spdx"
```

## CI / Workflow usage

### Smart build workflow

Workflow: `.github/workflows/device-build-smart.yml`

- Default for push/PR: `spdx_enabled=false`
- Manual run: set `spdx_enabled=true` in `workflow_dispatch`

### On-demand minimal workflow

Workflow: `.github/workflows/core-image-minimal-ondemand.yml`

- Manual run only
- Set `spdx_enabled=true` when SPDX output is required

## Output and artifact locations

When enabled:

1. Yocto writes SPDX output to:
  `yocto/build/tmp/deploy/images/qemuarm64/spdx/`
2. `scripts/process-sbom.sh` copies files to:
  `sbom/`
3. Workflows copy collected files to:
  `artifacts/spdx/`
4. Workflows always write:
  `artifacts/spdx-status.txt`

`spdx-status.txt` includes:

- `spdx_enabled=true|false`
- `spdx_files_collected=<count>`
- timestamp and a summary note

## Standards and tooling

Generated SPDX output remains compatible with:

- SPDX 2.2 / ISO/IEC 40110
- NTIA minimum SBOM elements
- Trivy, Anchore, OWASP Dependency-Check, SPDX tooling

## Status Notes

### Current

- The active SBOM path is Yocto SPDX (`create-spdx`) when enabled
- CI keeps SPDX disabled by default and records status in `artifacts/spdx-status.txt`
- `scripts/generate-sbom.sh` is maintained as a compatibility wrapper that
  delegates to SPDX processing

### Planned

- Improve release-facing compliance packaging guidance for SPDX and Vigiles
  outputs

### Investigating

- Optional CycloneDX export derived from SPDX outputs for consumers that require
  CycloneDX specifically
