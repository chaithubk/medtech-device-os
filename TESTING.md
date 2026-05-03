# Testing Guide

Manual test procedures for MedTech Device OS. Use this as a checklist when
reviewing PRs or after making significant changes.

---

## Table of Contents

- [Test Categories](#test-categories)
- [User Journey: Run a Release](#user-journey-run-a-release)
- [Developer Journey: Build and Boot](#developer-journey-build-and-boot)
- [Script Validation Tests](#script-validation-tests)
- [Documentation Link Tests](#documentation-link-tests)
- [CI Pipeline Tests](#ci-pipeline-tests)
- [Regression Checklist](#regression-checklist)

---

## Test Categories

| Category | Priority | Audience |
|---|---|---|
| [User Journey: Run a Release](#user-journey-run-a-release) | P0 | End users |
| [Developer Journey: Build and Boot](#developer-journey-build-and-boot) | P0 | Developers |
| [Script Validation Tests](#script-validation-tests) | P1 | Maintainers |
| [Documentation Link Tests](#documentation-link-tests) | P1 | Maintainers |
| [CI Pipeline Tests](#ci-pipeline-tests) | P0 | Maintainers |

---

## User Journey: Run a Release

### Prerequisites

- Ubuntu 22.04 (native, VM, or WSL2)
- Internet access
- No Docker installed (test the Docker-free path)

### Test 1.1: One-time setup

```bash
bash scripts/setup-host-qemu-prereqs.sh
```

**Expected:**
- No errors
- `qemu-system-aarch64` is available: `qemu-system-aarch64 --version`

### Test 1.2: Download and boot latest release

```bash
bash scripts/download-and-run-qemu.sh
```

**Expected:**
- [ ] Release metadata is fetched without error
- [ ] Bundle, manifest, and SHA256SUMS are downloaded
- [ ] Checksum verification passes ("Checksum verification passed")
- [ ] Bundle is extracted
- [ ] Boot info box is displayed with credentials and SSH command
- [ ] "Waiting for SSH daemon..." message appears
- [ ] Within 60 seconds: "✓ SSH port is open" or "✓ SSH daemon is responding"
- [ ] "Connect now: ssh -p 2222 root@localhost" is displayed

### Test 1.3: SSH connection

```bash
ssh -p 2222 root@localhost
# Password: root
```

**Expected:**
- [ ] SSH connects without error
- [ ] You see a shell prompt inside the QEMU VM
- [ ] `cat /etc/medtech-release` shows version info

### Test 1.4: Service verification (inside VM)

```bash
systemctl is-active mosquitto
systemctl is-active medtech-vitals-publisher
systemctl is-active medtech-edge-analytics
systemctl is-active medtech-clinician-ui
```

**Expected:**
- [ ] All four commands print `active`

### Test 1.5: MQTT data flow (inside VM)

```bash
mosquitto_sub -t "medtech/#" -v &
sleep 15
```

**Expected:**
- [ ] Within 15 seconds, see `medtech/vitals/latest` messages
- [ ] Within 20 seconds, see `medtech/predictions/sepsis` messages

### Test 1.6: Console mode

```bash
# In a new terminal (kill any running QEMU first)
bash scripts/download-and-run-qemu.sh --console
```

**Expected:**
- [ ] Terminal is connected to QEMU serial console
- [ ] Boot messages appear
- [ ] Login prompt appears
- [ ] Ctrl+A then X exits QEMU

### Test 1.7: No-wait-ssh mode

```bash
bash scripts/download-and-run-qemu.sh --no-wait-ssh &
```

**Expected:**
- [ ] QEMU boots without the SSH wait loop
- [ ] "(SSH wait skipped — --no-wait-ssh flag set)" message appears
- [ ] QEMU continues running in background

### Test 1.8: Dry-run mode

```bash
bash scripts/download-and-run-qemu.sh --dry-run
```

**Expected:**
- [ ] No QEMU is launched
- [ ] QEMU command is printed
- [ ] Downloaded artifacts are kept (no cleanup)

---

## Developer Journey: Build and Boot

### Prerequisites

- VS Code with Dev Containers extension
- Docker Desktop

### Test 2.1: Open in dev container

1. Open repository in VS Code
2. Click "Reopen in Container" when prompted

**Expected:**
- [ ] Container builds without error
- [ ] `postCreateCommand` (`quick-setup.sh`) runs and completes
- [ ] VS Code terminal is available

### Test 2.2: bitbake wrapper

In the container terminal:
```bash
# Should work from any directory
cd /tmp
bitbake --version
cd /workspace
bitbake --version
```

**Expected:**
- [ ] BitBake version is printed (not an error about root)
- [ ] No "Do not use Bitbake as root" error

### Test 2.3: Build single recipe (quick smoke test)

```bash
bitbake medtech-system
```

**Expected:**
- [ ] Build completes without error (uses sstate cache if available)
- [ ] No "ERROR:" lines in output

### Test 2.4: Full image build

```bash
bitbake core-image-medtech
```

**Expected:**
- [ ] Build completes (60–120 min first run)
- [ ] `.ext4` image exists:
  ```bash
  ls -lh yocto/build/tmp/deploy/images/qemuarm64/core-image-medtech-qemuarm64.ext4
  ```

### Test 2.5: Boot locally-built image

```bash
bash scripts/run-qemu.sh
```

**Expected:**
- [ ] QEMU boots
- [ ] Login prompt appears
- [ ] Services start correctly

---

## Script Validation Tests

### Test 3.1: package-release-artifacts.sh

```bash
# Requires a built image (Test 2.4 must pass first)
bash scripts/package-release-artifacts.sh --image-name core-image-medtech
```

**Expected:**
- [ ] Output: "=== Release bundle created ==="
- [ ] `artifacts/core-image-medtech-qemuarm64-bundle.tar.gz` exists
- [ ] `artifacts/core-image-medtech-qemuarm64-manifest.json` exists
- [ ] `artifacts/SHA256SUMS` exists

### Test 3.2: verify-release-package.sh

```bash
# Run after Test 3.1
bash scripts/verify-release-package.sh --image-name core-image-medtech
```

**Expected:**
- [ ] Output: "=== Release bundle verification passed ==="
- [ ] No checksum errors

### Test 3.3: Script deletion verification

```bash
# These files should NOT exist
ls scripts/run-ghcr-qemu.sh 2>&1
ls scripts/package-ghcr-artifacts.sh 2>&1
ls scripts/verify-ghcr-package.sh 2>&1
ls Dockerfile.qemu-artifacts 2>&1
```

**Expected:**
- [ ] All four commands produce "No such file or directory"

### Test 3.4: No GHCR references in user-facing content

```bash
grep -ri "GHCR" README.md scripts/README.md docs/ --include="*.md"
grep -ri "run-ghcr" README.md scripts/README.md docs/ --include="*.md"
grep -ri "package-ghcr" README.md scripts/README.md docs/ --include="*.md"
```

**Expected:**
- [ ] No matches (or only in explicitly historical/legacy context docs)

---

## Documentation Link Tests

### Test 4.1: Internal links in README.md

Check that all links in `README.md` pointing to `docs/` work:

```bash
# Check each link target exists
grep -o 'docs/[^)]*\.md' README.md | while read f; do
  [ -f "$f" ] && echo "OK: $f" || echo "MISSING: $f"
done
```

**Expected:** All links show "OK"

### Test 4.2: docs/README.md links

```bash
grep -o '\[.*\](\(.*\.md\))' docs/README.md | grep -o '([^)]*)' | tr -d '()' | while read f; do
  target="docs/$f"
  [ -f "$target" ] && echo "OK: $target" || echo "MISSING: $target"
done
```

**Expected:** All links show "OK"

---

## CI Pipeline Tests

### Test 5.1: CI uses renamed scripts

Confirm the workflow file references the new script names:

```bash
grep "package-release-artifacts" .github/workflows/device-build-smart.yml
grep "verify-release-package" .github/workflows/device-build-smart.yml
```

**Expected:**
- [ ] Both commands find matches
- [ ] No references to old names (package-ghcr, verify-ghcr)

### Test 5.2: CI workflow syntax

```bash
# Validate YAML syntax (requires python3-yaml)
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/device-build-smart.yml'))"
echo "YAML valid"
```

**Expected:** "YAML valid" with no errors

---

## Regression Checklist

Before merging a PR that touches scripts or documentation:

- [ ] `scripts/download-and-run-qemu.sh --help` works and shows new flags
- [ ] `scripts/download-and-run-qemu.sh --dry-run` works
- [ ] `scripts/package-release-artifacts.sh --help` works
- [ ] `scripts/verify-release-package.sh --help` works
- [ ] `scripts/bitbake` exists and is executable
- [ ] `.devcontainer/devcontainer.json` is valid JSON
- [ ] `yocto/meta-medtech/conf/layer.conf` parses correctly (test with `bitbake -p`)
- [ ] All doc files exist (see docs/README.md table)
- [ ] No broken Markdown syntax (headers, code blocks, links)
- [ ] CI workflow YAML is valid
