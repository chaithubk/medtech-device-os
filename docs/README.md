# MedTech Device OS Docs

This folder documents the CI-first debugging and hardening procedures used to detect Yocto package failures early, especially when local builds are not feasible.

## Documents

- [Yocto CI Failure Detection Runbook](./yocto-ci-failure-detection.md)

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
