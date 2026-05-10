# Testing Checklist

Quick manual tests to verify before merging a PR. Focus on the happy path.

---

## ✓ User Journey: Download & Run

```bash
bash scripts/download-and-run-qemu.sh
```
- [ ] Downloads without error
- [ ] Checksums pass
- [ ] QEMU boots and shows "✓ SSH daemon is responding" within 60s

```bash
ssh -p 2222 medadmin@localhost
```
- [ ] Connects successfully
- [ ] Shell prompt appears

```bash
systemctl status mosquitto medtech-vitals-publisher medtech-edge-analytics medtech-clinician-ui
```
- [ ] All show `active (running)`

```bash
mosquitto_sub -t "medtech/#" -v &
sleep 10
```
- [ ] See `medtech/vitals/latest` and `medtech/predictions/sepsis` topics

```bash
shutdown -h now
```

---

## ✓ Developer Journey: Build & Boot

```bash
# In VS Code: Ctrl+Shift+P → "Dev Containers: Reopen in Container"
```
- [ ] Container builds, `quick-setup.sh` completes

```bash
bitbake medtech-system
```
- [ ] Completes without ERROR

```bash
bitbake core-image-medtech
```
- [ ] Completes (60–120 min first run)
- [ ] `.ext4` file exists: `ls -lh yocto/build/tmp/deploy/images/qemuarm64/core-image-medtech-qemuarm64.ext4`

```bash
bash scripts/run-qemu.sh
```
- [ ] QEMU boots and reaches login prompt
- [ ] Services start (verify with `systemctl` as above)

---

## ✓ Release Packaging

```bash
bash scripts/package-release-artifacts.sh --image-name core-image-medtech
bash scripts/verify-release-package.sh --image-name core-image-medtech
```
- [ ] Both complete without error
- [ ] Bundle, manifest, and SHA256SUMS exist

---

## ✓ Build System Checks

```bash
# Wrapper works
bitbake --version
cd /tmp && bitbake --version && cd /workspace
```
- [ ] No "Do not use Bitbake as root" error

```bash
# Documentation links
grep -o 'docs/[^)]*\.md' README.md | while read f; do
  [ -f "$f" ] || echo "MISSING: $f"
done
```
- [ ] No output (all links valid)

```bash
# CI workflow YAML
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/device-build-smart.yml'))" && echo OK
```
- [ ] Prints "OK"

---

## Quick Checklist

- [ ] User can download and run
- [ ] Developer can build and boot
- [ ] Services start
- [ ] Release packaging works
- [ ] Docs links valid
- [ ] No obvious regressions

---

See **[docs/](docs/)** for guides and documentation.
