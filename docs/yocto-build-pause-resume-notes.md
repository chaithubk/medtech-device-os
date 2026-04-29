# Yocto Build Pause/Resume Notes

When running long-duration Yocto builds locally (e.g., `bitbake medtech-clinician-ui` or `bitbake core-image-medtech`), you may need to pause and later resume the build. This guide explains how to safely interrupt and resume builds without losing cached work.

## Why Pause/Resume is Safe

Yocto's `sstate` (shared state) cache writes task outputs immediately to disk as each task completes. The sstate cache is stored in `/workspace/yocto/sstate-cache/`. When you interrupt a build:

- ✅ All completed task outputs remain in sstate cache
- ✅ Partial or in-progress tasks are discarded (will rebuild if resumed)
- ✅ Build can resume from the last completed task boundary
- ✅ No recovery time penalty beyond re-running incomplete tasks

**Important:** Sstate cache is persistent across build interruptions. Resume by simply re-running `bitbake <target>` and BitBake will:
1. Detect already-completed tasks in sstate
2. Skip their do_fetch, do_compile, do_populate_sysroot, etc.
3. Continue from the first uncompleted task

## Three Ways to Pause

### Option 1: Graceful Interrupt (Recommended)

Press `Ctrl+C` while bitbake is running.

```bash
$ bitbake medtech-clinician-ui
... [tasks running] ...
^C
BitBake interrupted
```

**Behavior:**
- BitBake prints "BitBake interrupted" or similar
- Gracefully shuts down its worker processes
- Sstate cache remains intact
- Clean resume on next `bitbake medtech-clinician-ui` run

**Best for:** When you want to pause mid-build and expect to resume soon.

### Option 2: Wait for Task Boundary

Let the current task complete before stopping the machine or container.

**How to detect:** Watch the build output for lines like:
```
NOTE: Running task 1234 of 5678 (/workspace/yocto/meta-medtech/recipes-services/medtech-clinician-ui/medtech-clinician-ui_1.0.bb:do_compile)
```

When the next line appears (indicating the task just finished), you can safely stop.

**Best for:** If you prefer to let a long-running task finish before pausing (avoids partial compile state).

### Option 3: Forceful Kill (Last Resort)

If BitBake is hung or unresponsive, kill the process:

```bash
pkill -9 bitbake
```

**Behavior:**
- Immediately terminates BitBake (may leave a task partially complete)
- Sstate cache remains intact (newly finished tasks already written)
- On resume, the interrupted task will be re-run from scratch

**Best for:** Debugging or emergency stops only. Ctrl+C is preferred.

## Resuming a Paused Build

Simply re-run the same bitbake command:

```bash
$ bitbake medtech-clinician-ui
... [BitBake detects sstate cache] ...
NOTE: Resuming previous build. Checking sstate cache...
... [skips already-completed tasks] ...
NOTE: Running task 2567 of 5678 (first uncompleted task)
... [continues where it left off] ...
```

**Time to Resume:**
- First 30–60 seconds: BitBake scans sstate cache and re-parses recipes
- ~seconds: Skips thousands of already-completed tasks
- Resumes: Starts from the first uncompleted task

For a 4500+ task build with 4000+ tasks already cached, resuming may advance task counters from "1 of 5678" to "4001 of 5678" within a minute.

## What Gets Preserved

| State | Preserved? | Notes |
|-------|-----------|-------|
| **sstate-cache/** | ✅ Yes | Core persistent cache; survives any interruption |
| **downloads/** | ✅ Yes | Fetched sources; persist across builds |
| **build/tmp/work/** | ❌ Temporary | Rebuilt on next run; don't rely on this |
| **build/tmp/deploy/** | ❌ Temporary | Images/artifacts; regenerated on complete build |

## Checking Build Status Without Interrupting

To see current progress without stopping:

```bash
# In a separate terminal, watch the task log
tail -f /workspace/yocto/build/tmp/log/cooker/qemuarm64/console-latest.log
```

This shows which task is running without interrupting BitBake.

## Advanced: Selective Task Cleaning

If you want to force a recipe to rebuild on resume (e.g., if source changed):

```bash
$ bitbake -c cleansstate medtech-clinician-ui
$ bitbake medtech-clinician-ui  # Will rebuild from scratch
```

**Important:** `cleansstate` removes sstate **only for that recipe**, NOT its dependencies.

### cleansstate Scope

| What's Removed | What's Preserved |
|---|---|
| medtech-clinician-ui's compiled output | Qt6's sstate cache |
| medtech-clinician-ui's fetch state | meta-openembedded deps' sstate |
| | Downloaded sources in downloads/ |

### Example: Rebuild medtech-clinician-ui without rebuilding Qt6

```bash
$ bitbake -c cleansstate medtech-clinician-ui
$ bitbake medtech-clinician-ui
```

Result:
- medtech-clinician-ui rebuilds from scratch (~5–15 mins)
- Qt6 and all dependencies reused from sstate cache
- Total time: ~10 mins (vs 60+ mins for first build)

### Example: Clean everything (full rebuild, rarely needed)

```bash
$ rm -rf /workspace/yocto/sstate-cache/*
$ rm -rf /workspace/yocto/build/tmp/work/*
$ bitbake core-image-medtech  # Full rebuild, 2+ hours
```

Only do this if you suspect widespread cache corruption.

See [Yocto Local Recovery Notes](./yocto-local-recovery-notes.md) for more recovery patterns.

## Summary

- **Pause safely:** Ctrl+C at any time; sstate cache is immediately written
- **Resume:** Re-run `bitbake <target>`; BitBake skips cached tasks
- **Cost:** Minimal; sstate cache ensures only incomplete tasks are re-run
- **Preserve:** Keep `/workspace/yocto/sstate-cache/` and `/workspace/yocto/downloads/` across stops
