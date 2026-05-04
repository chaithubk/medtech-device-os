# MedTech Device OS — Documentation Index

Welcome to the MedTech Device OS documentation. Use this page to find the right
guide for your role.

---

## 🚀 I want to run a release on my machine

| Document | Description |
|---|---|
| [QUICK_START_USER.md](QUICK_START_USER.md) | **Start here** — download and boot in 5 minutes |
| [QUICK_REFERENCE.md](QUICK_REFERENCE.md) | Copy-paste commands for all common tasks |
| [DEPLOYMENT_TROUBLESHOOTING.md](DEPLOYMENT_TROUBLESHOOTING.md) | SSH issues, QEMU freezes, SCP errors |

---

## 👨‍💻 I want to build from source / develop recipes

| Document | Description |
|---|---|
| [QUICK_START_DEVELOPER.md](QUICK_START_DEVELOPER.md) | **Start here** — open container and build in 10 minutes |
| [BUILD_GUIDE.md](BUILD_GUIDE.md) | Complete build instructions, options, and troubleshooting |
| [LAYER_STRUCTURE.md](LAYER_STRUCTURE.md) | meta-medtech layout and recipe conventions |
| [RECIPES.md](RECIPES.md) | Recipe examples and how to add new services |
| [ARCHITECTURE.md](ARCHITECTURE.md) | System design, MQTT data flow, systemd chains |

---

## 🔧 I maintain the CI/CD pipeline or release process

| Document | Description |
|---|---|
| [CI_CD.md](CI_CD.md) | GitHub Actions workflow explanation |
| [RELEASE_PROCESS.md](RELEASE_PROCESS.md) | How releases are created and versioned |

---

## 📦 Technical reference docs

| Document | Description |
|---|---|
| [DISK_OPTIMIZATION.md](DISK_OPTIMIZATION.md) | Build disk pressure mitigation |
| [SBOM_STRATEGY.md](SBOM_STRATEGY.md) | SBOM generation and compliance |
| [yocto-ci-failure-detection.md](yocto-ci-failure-detection.md) | CI-first failure triage runbook |
| [yocto-fetch-and-mirror-notes.md](yocto-fetch-and-mirror-notes.md) | Fetch failures and mirrors |
| [yocto-generated-config-notes.md](yocto-generated-config-notes.md) | Generated config behavior |
| [yocto-local-recovery-notes.md](yocto-local-recovery-notes.md) | Local recovery steps |
| [yocto-single-recipe-build-notes.md](yocto-single-recipe-build-notes.md) | Fast recipe-only builds |
| [yocto-build-pause-resume-notes.md](yocto-build-pause-resume-notes.md) | Pausing and resuming builds |

---

## Not sure where to start?

- **Running the OS** → [QUICK_START_USER.md](QUICK_START_USER.md)
- **Building the OS** → [QUICK_START_DEVELOPER.md](QUICK_START_DEVELOPER.md)
- **Understanding the OS** → [ARCHITECTURE.md](ARCHITECTURE.md)
- **CI triage** → [yocto-ci-failure-detection.md](yocto-ci-failure-detection.md)
