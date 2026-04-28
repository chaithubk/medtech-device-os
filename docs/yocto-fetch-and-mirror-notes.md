# Yocto Fetch And Mirror Notes

This note explains common fetch warnings seen during local Yocto builds and when they matter.

## Typical Warning

You may see warnings like:

```text
WARNING: some-recipe do_fetch: Failed to fetch URL <upstream-url>, attempting MIRRORS if available
```

By itself, this is not a build failure.
It means BitBake could not fetch from the primary `SRC_URI` location and is trying configured mirrors.

## When It Is Safe To Ignore

It is usually safe to ignore if:

1. The build continues normally
2. The recipe later fetches successfully from a mirror
3. There is no later `ERROR: ... do_fetch`

In that case, the warning is only telling you that the primary upstream was unavailable.

## When It Is A Real Problem

It becomes a real issue if you later see:

1. `ERROR: ... do_fetch`
2. `Fetcher failure`
3. `Unable to fetch URL from any source`
4. Checksum mismatch errors

That means BitBake could not recover through mirrors and the build cannot proceed.

## Why This Happens Often In Local Builds

Common causes:

1. Old `http://` upstream sources are flaky or redirected
2. Corporate proxy or firewall rules block some upstreams
3. TLS or certificate-chain issues affect some hosts
4. An upstream source has moved or disappeared

This repo already includes local-only workarounds for environments where some upstream certificate chains fail inside the dev container.

## What To Do Locally

If the build is still moving, do nothing.
If it fails, first check whether it is a local network issue or a broken upstream.

Useful checks:

```bash
grep -E "WARNING: .*do_fetch|ERROR: .*do_fetch|Fetcher failure" yocto/build/build.log
```

If local setup looks stale or partially configured:

```bash
bash scripts/quick-setup.sh
```

## Practical Rule

Treat fetch warnings as informational until they become a later fetch error.

The build should only be considered broken when BitBake cannot fetch the source from either the primary upstream or a fallback mirror.
