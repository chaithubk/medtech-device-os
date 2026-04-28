# Yocto Generated Config Notes

This note explains which Yocto config files are source-controlled inputs and which are generated local build state.

## Source Of Truth

These files are the repo-owned inputs:

1. `yocto/conf/local.conf.sample`
2. `yocto/conf/bblayers.conf.sample`

They are the templates used to create the actual config inside a local build directory.

## Generated Local Build State

These files are generated for one local build directory:

1. `yocto/build/conf/local.conf`
2. `yocto/build/conf/bblayers.conf`

They are local working copies, not the source of truth.

## Why The Distinction Matters

This repo uses the sample files as the canonical configuration.
CI also recreates its build config from those sample files on every run.

That means:

1. Editing `yocto/build/conf/*` changes only your local build directory
2. Editing `yocto/conf/*.sample` affects future generated config and can affect CI
3. Generated files should generally not be committed

## Current Local Workflow

`quick-setup.sh` is designed to manage generated local config for you.
It can:

1. Create missing local config
2. Refresh stale `yocto/build/conf/bblayers.conf` from the sample
3. Add local-only workarounds to generated local config when needed

## Safe Rule To Follow

If you want to change repo-wide intended behavior, edit the sample files.
If you only want to repair or refresh your local build directory, regenerate the files under `yocto/build/conf`.

## Useful Recovery Commands

Regenerate local build config:

```bash
bash scripts/quick-setup.sh
```

Or copy from the samples explicitly:

```bash
cd /workspace/yocto/build
cp ../conf/local.conf.sample conf/local.conf
cp ../conf/bblayers.conf.sample conf/bblayers.conf
```
