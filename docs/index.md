# Documentation Index

Complete navigation for all MedTech Device OS documentation.

---

## Quick Navigation

### 🎯 By Role/Goal

**I just want to run a pre-built release (5 min)**
→ [getting-started/quick-start-user.md](getting-started/quick-start-user.md)

**I want to build from source (10 min)**
→ [getting-started/quick-start-developer.md](getting-started/quick-start-developer.md)

**I need all commands on one page**
→ [reference/quick-reference.md](reference/quick-reference.md)

**SSH login not working**
→ [guides/ssh-provisioning.md](guides/ssh-provisioning.md) (Troubleshooting section)

**I'm a developer - where do I start?**
→ [getting-started/quick-start-developer.md](getting-started/quick-start-developer.md) → [guides/build-guide.md](guides/build-guide.md)

**I maintain CI/CD and releases**
→ [maintainers/ci-cd.md](maintainers/ci-cd.md) → [maintainers/release-process.md](maintainers/release-process.md)

**I want to understand the architecture**
→ [reference/architecture-reference.md](reference/architecture-reference.md)

**I'm writing a new Yocto recipe**
→ [guides/recipes.md](guides/recipes.md) → [reference/layer-structure.md](reference/layer-structure.md)

**Image is too large / disk space issues**
→ [guides/disk-optimization.md](guides/disk-optimization.md)

**Yocto build is broken / acting weird**
→ [notes/](notes/) (Yocto troubleshooting)

---

## Complete File Index

### Getting Started

| File | Purpose | Audience |
|------|---------|----------|
| [getting-started/quick-start-user.md](getting-started/quick-start-user.md) | Download & run latest release in 5 min | End users |
| [getting-started/quick-start-developer.md](getting-started/quick-start-developer.md) | Build from source in 10 min | Developers |

### SSH & Security

| File | Purpose | Audience |
|------|---------|----------|
| [guides/first-boot-setup.md](guides/first-boot-setup.md) | First-boot interactive SSH key provisioning (public releases) | End users |
| [guides/ssh-provisioning.md](guides/ssh-provisioning.md) | SSH key setup, how it works, troubleshooting | Everyone |
| [guides/ssh-provisioning-advanced.md](guides/ssh-provisioning-advanced.md) | Technical deep dive, architecture, environment chain | DevOps/Maintainers |

### Build & Development

| File | Purpose | Audience |
|------|---------|----------|
| [guides/build-guide.md](guides/build-guide.md) | Complete build instructions & options | Developers |
| [guides/recipes.md](guides/recipes.md) | Writing Yocto recipes, conventions, examples | Recipe authors |
| [reference/layer-structure.md](reference/layer-structure.md) | meta-medtech organization & conventions | Developers |
| [reference/architecture-reference.md](reference/architecture-reference.md) | System design, MQTT flow, systemd chains | Architects/Developers |

### Operations & Troubleshooting

| File | Purpose | Audience |
|------|---------|----------|
| [guides/deployment-troubleshooting.md](guides/deployment-troubleshooting.md) | SSH, QEMU, SCP, boot issues | Everyone |
| [guides/disk-optimization.md](guides/disk-optimization.md) | Reducing image size, build disk pressure | Build engineers |
| [guides/sbom-strategy.md](guides/sbom-strategy.md) | SBOM generation, compliance | Compliance/Security |
| [reference/quick-reference.md](reference/quick-reference.md) | Copy-paste commands | Everyone |

### CI/CD & Releases

| File | Purpose | Audience |
|------|---------|----------|
| [maintainers/ci-cd.md](maintainers/ci-cd.md) | GitHub Actions pipeline explained | CI/CD engineers |
| [maintainers/release-process.md](maintainers/release-process.md) | How to create & manage releases | Maintainers |

### Yocto Build Notes

Located in [notes/](notes/) folder:

| File | Purpose |
|------|---------|
| [notes/yocto-build-pause-resume-notes.md](notes/yocto-build-pause-resume-notes.md) | Safely pause & resume long builds |
| [notes/yocto-ci-failure-detection.md](notes/yocto-ci-failure-detection.md) | Proactive CI failure triage runbook |
| [notes/yocto-fetch-and-mirror-notes.md](notes/yocto-fetch-and-mirror-notes.md) | Fetch warnings & mirrors |
| [notes/yocto-generated-config-notes.md](notes/yocto-generated-config-notes.md) | Generated vs source configs |
| [notes/yocto-local-recovery-notes.md](notes/yocto-local-recovery-notes.md) | Local build recovery steps |
| [notes/yocto-single-recipe-build-notes.md](notes/yocto-single-recipe-build-notes.md) | Why single-recipe builds are large |

---

## Document Types Explained

| Type | Example | When to use |
|------|---------|-------------|
| **Quick Start** | quick-start-user.md | Get running fast (5-10 min) |
| **Guide** | build-guide.md | Complete task reference |
| **Reference** | quick-reference.md, architecture-reference.md | Lookup & cheat sheets |
| **Troubleshooting** | deployment-troubleshooting.md | Fix problems |
| **Technical Deep Dive** | ssh-provisioning-advanced.md | Understand internals |
| **Notes** | yocto-*.md | Specific issue solutions |

---

## File Organization

```
docs/
├── readme.md (overview - start here)
├── index.md (this file - complete TOC)
│
├── getting-started/ (quick onboarding)
│   ├── quick-start-user.md
│   └── quick-start-developer.md
│
├── guides/ (detailed how-to)
│   ├── ssh-provisioning.md
│   ├── ssh-provisioning-advanced.md
│   ├── build-guide.md
│   ├── recipes.md
│   ├── deployment-troubleshooting.md
│   ├── disk-optimization.md
│   └── sbom-strategy.md
│
├── reference/ (lookup & reference)
│   ├── quick-reference.md
│   ├── architecture-reference.md
│   └── layer-structure.md
│
├── maintainers/ (for maintainers/releases)
│   ├── ci-cd.md
│   └── release-process.md
│
└── notes/ (Yocto build troubleshooting)
    ├── yocto-build-pause-resume-notes.md
    ├── yocto-ci-failure-detection.md
    ├── yocto-fetch-and-mirror-notes.md
    ├── yocto-generated-config-notes.md
    ├── yocto-local-recovery-notes.md
    └── yocto-single-recipe-build-notes.md
```

---

## Naming Convention

All documentation now follows consistent lowercase-dash naming:

- **Main guides:** `guide-name.md` (e.g., `ssh-provisioning.md`, `build-guide.md`)
- **Quick starts:** `quick-start-topic.md` (e.g., `quick-start-user.md`)
- **Reference:** `reference-name.md` (e.g., `quick-reference.md`, `architecture-reference.md`)
- **Advanced/Technical:** `topic-advanced.md` (e.g., `ssh-provisioning-advanced.md`)
- **Notes:** `yocto-topic-notes.md` (e.g., `yocto-build-pause-resume-notes.md`)
- **Hub files:** `readme.md`, `index.md`

---

## Migrating From Old Structure

**Old files** (CAPS naming) are being phased out. New files in organized folders use consistent lowercase-dash naming.

| Old | New |
|-----|-----|
| `README.md` | `readme.md` |
| `INDEX.md` | `index.md` |
| `QUICK_START_USER.md` | `getting-started/quick-start-user.md` |
| `QUICK_START_DEVELOPER.md` | `getting-started/quick-start-developer.md` |
| `SSH_PROVISIONING.md` | `guides/ssh-provisioning.md` |
| `SSH_PROVISIONING_ADVANCED.md` | `guides/ssh-provisioning-advanced.md` |
| `BUILD_GUIDE.md` | `guides/build-guide.md` |
| `DEPLOYMENT_TROUBLESHOOTING.md` | `guides/deployment-troubleshooting.md` |
| `CI_CD.md` | `maintainers/ci-cd.md` |
| `RELEASE_PROCESS.md` | `maintainers/release-process.md` |

Old CAPS files remain in place during transition. New links use lowercase-dash structure.

---

## Contributing

When adding new documentation:
1. Place in appropriate subfolder (getting-started, guides, reference, maintainers, notes)
2. Use lowercase-dash naming (e.g., `my-new-guide.md`)
3. Link to other docs using relative paths
4. Update this index.md with new entry

---

## See Also

- [readme.md](readme.md) — Quick overview
- [../../README.md](../../README.md) — Project README
- [../../TESTING.md](../../TESTING.md) — Test procedures
