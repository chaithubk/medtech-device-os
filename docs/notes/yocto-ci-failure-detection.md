# Yocto CI Failure Detection Runbook

This runbook documents the exact procedure used to proactively detect package and recipe failures in CI.

It is optimized for constrained GitHub-hosted runners where full local reproduction is expensive or impossible.

## Why This Process Exists

Yocto failures often appear one-by-one if the pipeline only runs a full image build. Typical examples:

- bad SRC_URI checksums
- stale or moved source URLs
- bad LIC_FILES_CHKSUM values
- invalid RDEPENDS package names
- build-time native toolchain failures (for example quilt-native)

This runbook front-loads detection so most failures are found in early stages.

## Key Principle

Separate concerns:

1. Build-time requirements: native tools and host dependencies needed to construct the image.
2. Runtime image requirements: packages that end up in target rootfs.

Build-time failures do not necessarily imply runtime bloat.

## End-to-End Procedure

### Phase 1: Static Recipe Audit (Fast)

Inspect all custom layer recipes and detect common metadata issues.

Checklist:

1. Enumerate custom recipes.
2. Extract SRC_URI, checksums, RDEPENDS, and BBCLASSEXTEND.
3. Look for duplicate checksum assignments or suspicious placeholders.
4. Look for invalid split package names in RDEPENDS.

Examples:

```bash
rg --files yocto/meta-medtech | rg '\\.bb$|\\.bbappend$'
rg -n 'SRC_URI\[sha256sum\]|SRC_URI\[md5sum\]|LIC_FILES_CHKSUM|RDEPENDS:\$\{PN\}|BBCLASSEXTEND' yocto/meta-medtech
```

### Phase 2: Source Integrity Verification (Out-of-Band)

Before relying on CI, verify upstream tarballs and license file checksums directly.

Checklist:

1. Download source archives from declared URLs.
2. Compute sha256 and compare with recipe.
3. Extract license files and compute md5 for LIC_FILES_CHKSUM.
4. Update recipe checksums if upstream values differ.

Examples:

```bash
curl --http1.1 -L --fail --retry 5 --retry-all-errors --retry-delay 2 -o paho.tar.gz https://files.pythonhosted.org/packages/source/p/paho-mqtt/paho-mqtt-1.6.1.tar.gz
sha256sum paho.tar.gz

mkdir -p paho-src && tar -xf paho.tar.gz -C paho-src --strip-components=1
md5sum paho-src/LICENSE.txt
```

### Phase 3: CI Preflight Gate (Before Full Build)

Run low-cost BitBake checks first.

Required preflight steps in CI:

1. `bitbake -n core-image-medtech`
2. `bitbake -k <custom-recipes> -c checkuri`
3. `bitbake -k <custom-recipes> -c fetch`

Purpose:

- fail fast on provider, URI, and checksum problems
- avoid burning hours on compile before fetch metadata is validated

### Phase 4: Full Build with Better Failure Surface

Run full build with:

1. `bitbake -k core-image-medtech` to expose multiple failures in one run.
2. Failure log collection that tails the latest `log.do_*` files.
3. Targeted log dump for known hotspots (quilt-native, custom fetch recipes).

This prevents a single opaque failure from hiding downstream issues.

### Phase 5: Runtime Policy Enforcement (Post-Build)

Even if build-time native devtools are required, block debug/dev payload in final image.

Enforce via image manifest checks:

1. Fail if manifest contains `-dbg`, `-dev`, `-staticdev`.
2. Fail if manifest contains known debug tools (`gdb`, `strace`, `perf`, `valgrind`, `quilt`).

This guarantees production image cleanliness independent of build graph complexity.

## Failure Pattern Catalog

### Pattern A: "Nothing RPROVIDES <package>"

Cause:

- invalid runtime package name in IMAGE_INSTALL or RDEPENDS.

Detection:

- `bitbake -n core-image-medtech`

Fix:

- replace fragile split names with stable package groups where appropriate (for example `python3-modules`), then tighten later if needed.

### Pattern B: do_fetch checksum mismatch

Cause:

- incorrect SRC_URI checksum in recipe.

Detection:

- `bitbake -c fetch` preflight
- manual `sha256sum` verification against downloaded source

Fix:

- update recipe checksum to verified source archive hash.

### Pattern C: LIC_FILES_CHKSUM mismatch

Cause:

- license checksum copied from wrong source version or old archive shape.

Detection:

- appears during unpack/configure/license checks
- proactive manual extraction + md5 verification catches it earlier

Fix:

- update LIC_FILES_CHKSUM to real md5 from extracted license file.

### Pattern D: native tool configure failure (for example quilt-native)

Cause:

- missing/fragile host prerequisites, environment mismatch, or transitive configure dependency.

Detection:

- full build logs (`log.do_configure`)
- targeted log extraction in CI failure step

Fix:

1. install missing host prerequisites in workflow
2. inspect exact failing configure log section
3. patch host deps or recipe assumptions based on log evidence

## Recommended Ongoing Workflow

For each pull request:

1. Run CI preflight gate first.
2. Run full build only if preflight passes.
3. Always collect failed task log tails.
4. Keep manifest policy gate mandatory.

For each new third-party recipe:

1. verify SRC_URI sha256 manually once
2. verify LIC_FILES_CHKSUM manually once
3. add to preflight `checkuri` and `fetch` target list

## Quick Triage Playbook

When CI fails, triage in this order:

1. provider failures (`Nothing RPROVIDES`)
2. fetch/checksum failures
3. license checksum failures
4. native configure/compile failures
5. post-build manifest policy failures

This ordering minimizes time wasted on expensive stages.

## Notes for Low-Resource Local Machines

If local full builds are not practical:

1. run only metadata/static checks locally (`rg` audits)
2. verify remote source checksums with direct `curl + sha256sum + md5sum`
3. rely on CI preflight for bitbake dependency/URI/fetch validation

This gives strong confidence without local high-resource execution.
