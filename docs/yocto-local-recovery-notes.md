# Yocto Local Recovery Notes

This note collects safe recovery commands for common local Yocto build problems in the dev container.

## 1. Local Setup Feels Incomplete Or Stale

Symptoms:

1. Missing layers
2. Missing generated config
3. `bitbake` wrapper not installed yet

Run:

```bash
bash scripts/quick-setup.sh
```

This is the first recovery step for most local setup issues.

## 2. Generated Build Config Looks Wrong

If your local `yocto/build/conf` files are stale or were manually changed in a bad way:

```bash
bash scripts/quick-setup.sh
```

If you want to force explicit replacement from samples:

```bash
cd /workspace/yocto/build
cp ../conf/local.conf.sample conf/local.conf
cp ../conf/bblayers.conf.sample conf/bblayers.conf
```

## 3. BitBake Is Stuck Reconnecting To The Server

Symptoms:

1. `NOTE: Reconnecting to bitbake server...`
2. `No reply from server in 30s`

Safe reset:

```bash
cd /workspace
pkill -f 'bitbake|cooker' || true
rm -f yocto/build/bitbake.lock yocto/build/bitbake.sock yocto/build/hashserve.sock
```

Then rerun:

```bash
bitbake medtech-clinician-ui
```

## 4. One Recipe Needs A Fresh Rebuild

```bash
bitbake -c cleansstate medtech-clinician-ui
bitbake medtech-clinician-ui
```

Use this only when you need to discard cached output for that recipe.
Do not default to it for normal iteration.

## 5. Build Fails During Fetch

First, check whether it is only a warning or a real error:

```bash
grep -E "WARNING: .*do_fetch|ERROR: .*do_fetch|Fetcher failure" yocto/build/build.log
```

If it is a real fetch failure, rerun local setup and try again:

```bash
bash scripts/quick-setup.sh
bitbake medtech-clinician-ui
```

## 6. Build Fails Because BitBake Is Running As Root

The local wrapper is designed to avoid this.
Use:

```bash
bitbake medtech-clinician-ui
```

Instead of manually invoking BitBake from a root shell with custom environment setup.

## Practical Rule

For most local issues, try these in order:

1. `bash scripts/quick-setup.sh`
2. Reset stale BitBake server state if needed
3. Rebuild the affected recipe
4. Use `cleansstate` only when necessary
