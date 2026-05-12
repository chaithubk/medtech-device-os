# Documentation Index

Canonical index for all project documentation.
Use [readme.md](readme.md) for the quick entry page.

## Quick Navigation

| Goal | Start Here |
|---|---|
| Run the latest release in QEMU | [Quick Start for Users](getting-started/quick-start-user.md) |
| Build from source | [Quick Start for Developers](getting-started/quick-start-developer.md) |
| SSH troubleshooting | [SSH Provisioning Guide](guides/ssh-provisioning.md) |
| Deployment troubleshooting | [Deployment Troubleshooting](guides/deployment-troubleshooting.md) |
| Build and Yocto workflow details | [Build Guide](guides/build-guide.md) |
| Recipe authoring guidance | [Recipe Authoring Guide](guides/recipes.md) |
| Command reference | [Quick Reference](reference/quick-reference.md) |
| Architecture and service flow | [Architecture Reference](reference/architecture-reference.md) |
| Layer organization | [Layer Structure Reference](reference/layer-structure.md) |
| CI/CD pipeline | [CI/CD Guide](maintainers/ci-cd.md) |
| Release process | [Release Process](maintainers/release-process.md) |

## Full File Index

### Getting Started

| File | Purpose | Audience |
|---|---|---|
| [Quick Start for Users](getting-started/quick-start-user.md) | Download and run a prebuilt image quickly | Users |
| [Quick Start for Developers](getting-started/quick-start-developer.md) | Build and boot from source | Developers |

### Security and Access

| File | Purpose | Audience |
|---|---|---|
| [First Boot Setup](guides/first-boot-setup.md) | First-boot SSH onboarding for public images | Users |
| [SSH Provisioning Guide](guides/ssh-provisioning.md) | Standard SSH setup and troubleshooting | Everyone |
| [Advanced SSH Provisioning](guides/ssh-provisioning-advanced.md) | Implementation details and environment chain | Maintainers |

### Build and Development

| File | Purpose | Audience |
|---|---|---|
| [Build Guide](guides/build-guide.md) | Build workflow, options, and operational notes | Developers |
| [Recipe Authoring Guide](guides/recipes.md) | Recipe structure, conventions, and examples | Recipe authors |
| [Layer Structure Reference](reference/layer-structure.md) | Layout and conventions for the custom layer | Developers |
| [Architecture Reference](reference/architecture-reference.md) | Runtime architecture and service dependencies | Developers/Architects |

### Operations and Compliance

| File | Purpose | Audience |
|---|---|---|
| [Deployment Troubleshooting](guides/deployment-troubleshooting.md) | QEMU, SSH, SCP, and boot diagnostics | Everyone |
| [Disk Optimization Guide](guides/disk-optimization.md) | Build storage and image size optimization | Build engineers |
| [SBOM Strategy](guides/sbom-strategy.md) | SBOM generation and release compliance workflow | Security/Compliance |
| [Quick Reference](reference/quick-reference.md) | High-frequency command cheat sheet | Everyone |

### Maintainers

| File | Purpose | Audience |
|---|---|---|
| [CI/CD Guide](maintainers/ci-cd.md) | CI/CD workflow design and guardrails | Maintainers |
| [Release Process](maintainers/release-process.md) | Versioning and release promotion process | Maintainers |

### Yocto Notes

| File | Purpose |
|---|---|
| [Yocto Build Pause and Resume Notes](notes/yocto-build-pause-resume-notes.md) | Pause and resume long Yocto builds |
| [Yocto CI Failure Detection Notes](notes/yocto-ci-failure-detection.md) | CI-first failure detection and triage |
| [Yocto Fetch and Mirror Notes](notes/yocto-fetch-and-mirror-notes.md) | Source fetch failures and mirror strategy |
| [Yocto Generated Config Notes](notes/yocto-generated-config-notes.md) | Generated file handling and config boundaries |
| [Yocto Local Recovery Notes](notes/yocto-local-recovery-notes.md) | Recovery playbook for broken local state |
| [Yocto Single Recipe Build Notes](notes/yocto-single-recipe-build-notes.md) | Why single-recipe builds still consume space |

## Contributing Rules

1. Keep this file as the complete index.
2. Keep [readme.md](readme.md) as a lightweight entry page.
3. Use lowercase-dash names for new documents.
4. Use relative links and verify them after changes.

## See Also

- [Documentation Entry Page](readme.md)
- [Project README](../README.md)
- [Testing Guide](../TESTING.md)
