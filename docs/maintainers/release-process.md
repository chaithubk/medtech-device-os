# Release Process

How MedTech Device OS releases are created, versioned, and distributed.

---

## Table of Contents

- [Overview](#overview)
- [Release Artifacts](#release-artifacts)
- [Release Tagging Strategy](#release-tagging-strategy)
- [Naming Conventions](#naming-conventions)
- [When to Create Tags](#when-to-create-tags)
- [When to Create Prereleases](#when-to-create-prereleases)
- [When to Create Stable Releases](#when-to-create-stable-releases)
- [How to Promote a Tagged Build to Release](#how-to-promote-a-tagged-build-to-release)
- [Reproducibility and Traceability](#reproducibility-and-traceability)
- [Retention and Cleanup](#retention-and-cleanup)
- [Release Checklist](#release-checklist)

---

## Overview

Build workflows publish prerelease/dev artifacts automatically. Stable
semantic-version releases are created by promoting an existing prerelease
**without rebuilding**. This separation ensures:

- Every published asset is traceable to a specific commit and build run.
- Stable releases are deterministic — the exact bytes tested as a prerelease are
  what end users download.
- Storage is bounded — old prereleases are automatically purged.

```
PR Build         Push to main          Manual dispatch        Stable release
────────         ────────────          ───────────────        ─────────────
Artifact only    dev-main-SHA-rN.A     dev-manual-SHA-rN.A    vMAJOR.MINOR.PATCH
(no release)     prerelease            prerelease (opt-in)    (promoted, no rebuild)
30-day GHA       retained up to 10     manual cleanup         permanent
```

Before any long Yocto build starts, CI runs a fast-fail sanity job that:
- validates YAML syntax for workflows and composite actions
- validates shell script syntax with `bash -n`

This catches configuration errors early and avoids spending hours in a build
that will fail due to workflow/script syntax issues.

---

## Release Artifacts

Each release contains exactly three files:

| File | Description |
|---|---|
| `core-image-medtech-qemuarm64-bundle.tar.gz` | Kernel image, root filesystem (`.ext4`), and QEMU boot config |
| `core-image-medtech-qemuarm64-manifest.json` | Build metadata and per-file SHA256 checksums |
| `SHA256SUMS` | SHA256 checksums for the bundle and manifest |

### Bundle layout

```
payload/
├── image/
│   ├── Image-qemuarm64.bin                             # Linux kernel
│   ├── core-image-medtech-qemuarm64-<ts>.rootfs.ext4  # Root filesystem
│   └── dtb/                                            # Device tree blobs (optional)
└── metadata/
    ├── manifest.json
    ├── core-image-medtech-qemuarm64.qemuboot.conf
    └── core-image-medtech-qemuarm64-<ts>.rootfs.manifest
```

---

## Release Tagging Strategy

| Release type | Tag pattern | Created by | Prerelease |
|---|---|---|---|
| PR build | _(no tag)_ | CI (artifact only) | n/a |
| Main branch build | `dev-main-<sha7>-r<run>.<attempt>` | Push to `main` trigger | Yes |
| Manual build | `dev-manual-<sha7>-r<run>.<attempt>` | `workflow_dispatch` with `publish_prerelease=true` | Yes |
| Stable release | `vMAJOR.MINOR.PATCH` | `promote-prerelease-release.yml` | No |

All tags are immutable. Prerelease tags are never overwritten; they are purged
on a rolling basis (see [Retention and Cleanup](#retention-and-cleanup)).

---

## Naming Conventions

### Prerelease tags

```
dev-main-c16c183-r111.1
│   │     │       │  └── Run attempt (re-runs increment this)
│   │     │       └───── GitHub Actions run number
│   │     └───────────── 7-character commit SHA
│   └─────────────────── Trigger type: main push
└─────────────────────── Channel prefix
```

For manual dispatches: `dev-manual-<sha7>-r<run>.<attempt>`

### Stable tags

```
v1.2.3
│ │ └── Patch (backward-compatible bug fixes)
│ └──── Minor (new features, backward-compatible)
└────── Major (breaking changes or milestone releases)
```

Follow [Semantic Versioning 2.0.0](https://semver.org/).

### Branches

| Branch | Purpose |
|---|---|
| `main` | Integration branch; all PRs target here |
| `release/vMAJOR.MINOR` | Long-term support branch (if needed) |
| `feature/*` | Feature development |
| `fix/*` | Bug fix branches |

---

## When to Create Tags

### Automatic (via CI)

- **Every successful push to `main`** creates a `dev-main-*` prerelease tag.
  No manual action required.

### Manual (developer decision)

Create a tag manually only when:

1. **A prerelease has been validated** and is ready for promotion to stable.
   The promotion workflow creates the `vMAJOR.MINOR.PATCH` tag automatically
   from your selected source prerelease — you do not need to tag manually.

2. **A long-term support (LTS) branch** is branched from a stable tag for
   backport maintenance.

> **Do not** push `v*` tags directly — always use the promotion workflow to
> ensure release notes are rendered correctly and assets are consistent.

---

## When to Create Prereleases

| Situation | Create prerelease? | How |
|---|---|---|
| Merge PR to `main` | Yes (automatic) | Push trigger |
| Validate a build without publishing | No | `workflow_dispatch` → `publish_prerelease=false` |
| Test a specific config (SPDX, Vigiles) | Yes (optional) | `workflow_dispatch` → `publish_prerelease=true` |
| Reproduce a prior build | No — checkout the commit and build locally | See [Reproducibility](#reproducibility-and-traceability) |

---

## When to Create Stable Releases

Create a stable release when **all of the following are true**:

- [ ] The prerelease has been booted and validated in QEMU.
- [ ] First-boot SSH provisioning has been tested end-to-end.
- [ ] All post-build policy checks passed (no debug packages, Python sanity).
- [ ] SBOM / Vigiles scan reviewed (if applicable).
- [ ] Any known issues are documented or triaged.
- [ ] The team has agreed the prerelease is production-ready.

Use the promotion workflow — never rebuild for a stable release.

---

## How to Promote a Tagged Build to Release

1. Identify the prerelease tag to promote (e.g., `dev-main-c16c183-r111.1`).
2. Go to **Actions → Promote Prerelease To Stable Release**
   (`.github/workflows/promote-prerelease-release.yml`).
3. Click **Run workflow** and fill in:

   | Input | Value | Notes |
   |---|---|---|
   | `source_tag` | `dev-main-c16c183-r111.1` | Must be an existing prerelease |
   | `release_strategy` | `patch` / `minor` / `major` / `custom` | Determines version bump |
   | `version` | `v1.0.0` | Required only when `release_strategy=custom` |
   | `make_latest` | `true` | Mark as latest on GitHub |

4. The workflow:
   - Validates the source is a prerelease with assets.
   - Computes the next semver tag.
   - Downloads all assets from the source prerelease.
   - Renders stable release notes from the template.
   - Creates a new GitHub Release tagged `vMAJOR.MINOR.PATCH`.

5. Verify the new release on GitHub Releases — confirm assets and notes are correct.

> **No Yocto rebuild occurs.** The promoted release contains the exact same
> artifacts that were tested as a prerelease.

---

## Reproducibility and Traceability

Every release can be reproduced from source:

```bash
# 1. Find the commit SHA in the release notes or manifest
COMMIT="c16c183..."

# 2. Checkout and set up
git clone <repo-url>
git checkout "$COMMIT"
bash scripts/quick-setup.sh

# 3. Build
cd yocto/build
source ../poky/oe-init-build-env .
bitbake core-image-medtech
```

Traceability chain:
```
GitHub Release tag
  └── release notes (SHORT_SHA, COMMIT)
       └── manifest.json (full commit SHA, layer SHAs, package list)
            └── git log / git show (recipe changes, layer versions)
```

---

## Retention and Cleanup

### Prerelease (dev-main-*)

- **Automatic**: The `purge-old-prereleases` job runs after every push to `main`
  and deletes the oldest `dev-main-*` releases beyond the last 10.
- Both the GitHub Release and the corresponding git tag are deleted.
- Assets attached to deleted releases are also removed from GitHub storage.

### Prerelease (dev-manual-*)

- No automatic cleanup. Delete manually via GitHub UI or `gh release delete`.
- Convention: delete after validation is complete or within 30 days.

### GitHub Actions artifacts

- Build artifacts (uploaded via `actions/upload-artifact`) expire after 30 days.
- Debug artifacts (failed builds) expire after 30 days.
- Private Vigiles bundles expire after 14 days.

### Stable releases (v*)

- Never automatically deleted. Treat as permanent.

---

## Release Checklist

Use this checklist when deciding whether to promote a prerelease to stable.

**Validation**
- [ ] Image boots in QEMU without kernel panic or critical errors.
- [ ] First-boot SSH provisioning completes successfully (`public-hardened`).
- [ ] SSH login works after provisioning: `ssh -i ~/.ssh/id_medtech -p 2222 medadmin@localhost`.
- [ ] No unexpected services running (`systemctl list-units --failed`).
- [ ] Application stack (MedTech services) starts and responds.

**Security**
- [ ] No `-dbg`, `-dev`, or debug-tooling packages in image manifest.
- [ ] Password authentication is disabled.
- [ ] Root login is disabled.
- [ ] Vigiles CVE report reviewed (if VIGILES_ENABLED build was run).

**Artifacts**
- [ ] `sha256sum -c SHA256SUMS` passes on all three assets.
- [ ] Manifest JSON is present and well-formed.
- [ ] Bundle extracts cleanly and contains kernel + rootfs.

**Documentation**
- [ ] Release notes are accurate (SSH mode, version, commit link).
- [ ] `docs/` content is up to date for this release.


---

## Creating the Release Bundle (local)

If you have built the image locally and want to create the release bundle:

```bash
# Package the artifacts
bash scripts/package-release-artifacts.sh --image-name core-image-medtech

# Verify integrity
bash scripts/verify-release-package.sh --image-name core-image-medtech
```

Output is in the `artifacts/` directory.

---

## Verifying a Release

After downloading a release:

```bash
# Download the release files
# (done automatically by download-and-run-qemu.sh)

# Verify checksums manually
sha256sum -c SHA256SUMS

# Or use the helper script
bash scripts/verify-release-package.sh --image-name core-image-medtech --output-dir ./my-download-dir
```

---

## Running a Release

```bash
# Latest release (most users)
bash scripts/download-and-run-qemu.sh

# Specific release tag
bash scripts/download-and-run-qemu.sh --release dev-abc1234
```

See [../getting-started/quick-start-user.md](../getting-started/quick-start-user.md)
for full instructions.

---

## Status Notes

### Current

- Separate prerelease and stable channels
- Manual stable promotion with semantic version strategy
- Stable releases created from prerelease assets (no rebuild)

### Planned

- Keep prerelease build generation in CI and stable publication in promotion
    workflow to avoid accidental rebuild divergence

### Investigating

- Whether to enforce additional release-gate checks before promotion
    (for example, requiring specific compliance artifacts)
