# MedTech Device OS Docs

This folder documents the CI-first debugging and hardening procedures used to detect Yocto package failures early, especially when local builds are not feasible.

## Quick Index

Use this as the entry point for troubleshooting and build reliability work.

For deployment and runtime steps, start at [../README.md#deployment](../README.md#deployment).

| Document | When to use it |
| --- | --- |
| [Yocto CI Failure Detection Runbook](./yocto-ci-failure-detection.md) | CI build failed and you need a fast, repeatable triage path. |
| [Yocto Fetch And Mirror Notes](./yocto-fetch-and-mirror-notes.md) | Source fetches fail, mirrors are slow, or checksum/download issues occur. |
| [Yocto Generated Config Notes](./yocto-generated-config-notes.md) | Generated config files drift or CI/local config behavior differs. |
| [Yocto Local Recovery Notes](./yocto-local-recovery-notes.md) | Local dev container or workstation is broken and needs recovery steps. |
| [Yocto Single-Recipe Build Notes](./yocto-single-recipe-build-notes.md) | You want to iterate on one recipe without rebuilding the full image. |
| [Yocto Build Pause/Resume Notes](./yocto-build-pause-resume-notes.md) | You need to safely pause/resume long builds. |
| [Disk Optimization Strategy](./DISK_OPTIMIZATION.md) | Disk space is tight (especially in CI runners). |
| [SBOM Strategy](./SBOM_STRATEGY.md) | You need SBOM generation, validation, and supply-chain guidance. |

## Recommended Reading Order

1. Start with the [Yocto CI Failure Detection Runbook](./yocto-ci-failure-detection.md).
2. If failures involve downloads, continue with [Yocto Fetch And Mirror Notes](./yocto-fetch-and-mirror-notes.md).
3. For config drift and reproducibility, read [Yocto Generated Config Notes](./yocto-generated-config-notes.md) and [Yocto Local Recovery Notes](./yocto-local-recovery-notes.md).
4. Use [Yocto Single-Recipe Build Notes](./yocto-single-recipe-build-notes.md) for faster local iteration.
5. Add [Disk Optimization Strategy](./DISK_OPTIMIZATION.md) and [SBOM Strategy](./SBOM_STRATEGY.md) for CI hardening and compliance.

## Documents

- [Yocto CI Failure Detection Runbook](./yocto-ci-failure-detection.md)
- [Yocto Fetch And Mirror Notes](./yocto-fetch-and-mirror-notes.md)
- [Yocto Generated Config Notes](./yocto-generated-config-notes.md)
- [Yocto Local Recovery Notes](./yocto-local-recovery-notes.md)
- [Yocto Single-Recipe Build Notes](./yocto-single-recipe-build-notes.md)
- [Yocto Build Pause/Resume Notes](./yocto-build-pause-resume-notes.md)
- [Disk Optimization Strategy](./DISK_OPTIMIZATION.md)
- [SBOM Strategy](./SBOM_STRATEGY.md)

## Local vs CI Build Notes

See the main repository README for:

1. Local dev-container setup
2. Single-recipe local builds
3. CI-impacting files vs local-only files
4. Local reproducibility workarounds such as non-root BitBake, host packages, and local-only connectivity handling

## Goal

Give maintainers a repeatable process to:

1. Catch dependency/provider issues before long builds.
2. Catch fetch/checksum/license issues before compile.
3. Separate build-time native tool failures from runtime image content.
4. Enforce no debug/dev payloads in the final image.
