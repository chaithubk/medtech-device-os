# MedTech Device OS — Documentation

Welcome to MedTech Device OS documentation. 

For complete navigation guide, see **[index.md](index.md)**.

---

## 🚀 Getting Started

| Document | Description |
|---|---|
| [getting-started/quick-start-user.md](getting-started/quick-start-user.md) | Download and boot in 5 min (no Docker required) |
| [getting-started/quick-start-developer.md](getting-started/quick-start-developer.md) | Build from source in 10 min |

---

## 🔐 SSH & Access

| Document | Description |
|---|---|
| [guides/ssh-provisioning.md](guides/ssh-provisioning.md) | SSH key setup, quick start & troubleshooting |
| [guides/ssh-provisioning-advanced.md](guides/ssh-provisioning-advanced.md) | Technical deep dive (architecture, environment chain) |

---

## 📚 Reference & Guides

| Document | Description |
|---|---|
| [reference/quick-reference.md](reference/quick-reference.md) | Copy-paste commands cheat sheet |
| [reference/architecture-reference.md](reference/architecture-reference.md) | System design & components |
| [reference/layer-structure.md](reference/layer-structure.md) | Yocto meta-layer organization |
| [guides/build-guide.md](guides/build-guide.md) | Complete build instructions |
| [guides/recipes.md](guides/recipes.md) | Writing Yocto recipes |
| [guides/deployment-troubleshooting.md](guides/deployment-troubleshooting.md) | SSH, QEMU, SCP issues |
| [guides/disk-optimization.md](guides/disk-optimization.md) | Reducing image size |
| [guides/sbom-strategy.md](guides/sbom-strategy.md) | SBOM generation & compliance |

---

## 🔧 Maintainers

| Document | Description |
|---|---|
| [maintainers/ci-cd.md](maintainers/ci-cd.md) | GitHub Actions pipeline details |
| [maintainers/release-process.md](maintainers/release-process.md) | How releases are created |

---

## 📋 Yocto Build Notes

Located in **[notes/](notes/)** folder:

| Document | Description |
|---|---|
| [notes/yocto-build-pause-resume-notes.md](notes/yocto-build-pause-resume-notes.md) | Pausing and resuming builds |
| [notes/yocto-ci-failure-detection.md](notes/yocto-ci-failure-detection.md) | CI-first failure triage |
| [notes/yocto-fetch-and-mirror-notes.md](notes/yocto-fetch-and-mirror-notes.md) | Fetch failures & mirrors |
| [notes/yocto-generated-config-notes.md](notes/yocto-generated-config-notes.md) | Config file management |
| [notes/yocto-local-recovery-notes.md](notes/yocto-local-recovery-notes.md) | Build recovery steps |
| [notes/yocto-single-recipe-build-notes.md](notes/yocto-single-recipe-build-notes.md) | Fast single-recipe builds |

---

## 📂 File Organization

```
docs/
├── readme.md (this file)
├── index.md (complete TOC)
├── getting-started/
│   ├── quick-start-user.md
│   └── quick-start-developer.md
├── guides/
│   ├── ssh-provisioning.md
│   ├── ssh-provisioning-advanced.md
│   ├── build-guide.md
│   ├── recipes.md
│   ├── deployment-troubleshooting.md
│   ├── disk-optimization.md
│   └── sbom-strategy.md
├── reference/
│   ├── quick-reference.md
│   ├── architecture-reference.md
│   └── layer-structure.md
├── maintainers/
│   ├── ci-cd.md
│   └── release-process.md
└── notes/
    ├── yocto-build-pause-resume-notes.md
    ├── yocto-ci-failure-detection.md
    ├── yocto-fetch-and-mirror-notes.md
    ├── yocto-generated-config-notes.md
    ├── yocto-local-recovery-notes.md
    └── yocto-single-recipe-build-notes.md
```

---

**Note:** Old CAPS-named files (README.md, INDEX.md, etc.) are being phased out.  
Use the new lowercase-dash structure above.

See [index.md](index.md) for complete navigation by topic.
