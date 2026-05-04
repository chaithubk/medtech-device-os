# Release Process

How MedTech Device OS releases are created, versioned, and distributed.

---

## Overview

Releases are published automatically by the CI pipeline when code is merged to
the `main` branch. Each release consists of a QEMU-bootable image bundle
distributed via GitHub Releases — no Docker required.

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
| Stable (production) | `latest` | Every push to `main` |
| Development (pre-release) | `dev-<sha>` | Manual `workflow_dispatch` runs |

**Note:** The `latest` tag is updated (overwritten) on every successful `main`
push. There is no semantic versioning at this stage. Future milestones may
introduce `v1.0.0`-style tags.

---

## How to Trigger a Release

### Automatic (recommended)

Merge a PR to `main`. The CI pipeline runs automatically and, if successful,
creates or updates the `latest` release.

### Manual pre-release

Go to the repository on GitHub → **Actions** → **Smart Device OS Build** →
**Run workflow**. This creates a `dev-<sha>` pre-release for testing without
affecting the `latest` tag.

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

A future milestone will introduce:
- `v1.0.0`-style release tags
- Changelog generation
- Separate stable and development release channels
- Changelog auto-generation from PR descriptions
