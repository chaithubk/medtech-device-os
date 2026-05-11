# Release Process

How MedTech Device OS releases are created, versioned, and distributed.

---

## Overview

Build workflows publish prerelease/dev artifacts, and stable semantic-version
releases are created by promoting an existing prerelease (no rebuild). The
public release payload remains a durable, runnable image bundle via GitHub
Releases.

---

## Release Artifacts

Each release contains three files:

| File | Description |
|---|---|
| `core-image-medtech-qemuarm64-bundle.tar.gz` | Kernel image, root filesystem (`.ext4`), optional DTBs |
| `core-image-medtech-qemuarm64-manifest.json` | Build metadata and per-file SHA256 checksums |
| `SHA256SUMS` | SHA256 checksums for the bundle and manifest |

### Bundle contents

```
payload/
├── image/
│   ├── Image-qemuarm64.bin                             # Linux kernel
│   ├── core-image-medtech-qemuarm64-<timestamp>.rootfs.ext4  # Root filesystem
│   └── dtb/                                            # Device tree blobs (optional)
│       └── *.dtb
└── metadata/
    ├── manifest.json                                   # Package list + checksums
    ├── core-image-medtech-qemuarm64.qemuboot.conf      # QEMU boot config
    ├── core-image-medtech-qemuarm64-<timestamp>.rootfs.manifest
    └── core-image-medtech-qemuarm64.testdata.json
```

---

## Release Tagging Strategy

| Release type | Tag | When |
|---|---|---|
| Development (pre-release) | `dev-*` | Push to `main` and eligible manual workflow runs |
| Stable (production) | `vMAJOR.MINOR.PATCH` | Manual promotion from a prerelease |

Prerelease tags are unique and never overwritten. Stable semver tags are created
through the promotion workflow using one of: `patch`, `minor`, `major`, or
`custom` version selection.

---

## How to Trigger a Release

### Automatic prerelease

Merge a PR to `main`. The CI pipeline runs automatically and publishes a
prerelease/dev release with versioned artifacts.

### Manual prerelease

Go to the repository on GitHub → **Actions** → **Smart Device OS Build** →
**Run workflow**. This creates a prerelease/dev release for testing without
creating a stable semver release.

### Manual stable release promotion (no rebuild)

Go to **Actions** → **Promote Prerelease To Stable Release**
(`.github/workflows/promote-prerelease-release.yml`) and provide:
- `source_tag`: existing prerelease tag to promote.
- `release_strategy`: `patch`, `minor`, `major`, or `custom`.
- `version`: required when using `custom` (format `vMAJOR.MINOR.PATCH`).

This workflow reuses previously built assets from the source prerelease and
publishes a stable release without running Yocto again.

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

See [QUICK_START_USER.md](QUICK_START_USER.md) for full instructions.

---

## Future: Semantic Versioning

Implemented in current process:
- Separate prerelease and stable channels
- Manual stable promotion with semantic version strategy
- Stable releases created from prerelease assets (no rebuild)
