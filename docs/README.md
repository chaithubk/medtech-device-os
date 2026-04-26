# MedTech Device OS Docs

This folder documents the CI-first debugging and hardening procedures used to detect Yocto package failures early, especially when local builds are not feasible.

## Documents

- [Yocto CI Failure Detection Runbook](./yocto-ci-failure-detection.md)

## Goal

Give maintainers a repeatable process to:

1. Catch dependency/provider issues before long builds.
2. Catch fetch/checksum/license issues before compile.
3. Separate build-time native tool failures from runtime image content.
4. Enforce no debug/dev payloads in the final image.
