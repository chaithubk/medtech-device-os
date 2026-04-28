# Yocto Single-Recipe Build Notes

This note explains why running a single Yocto recipe build can still schedule a large number of tasks.

## Why `bitbake medtech-clinician-ui` Still Does A Lot Of Work

Building one recipe in Yocto does not mean building only one source package in isolation.
It means building that target plus everything required for it.

For `medtech-clinician-ui`, BitBake may need to build:

1. The recipe itself
2. Target-side library dependencies such as Qt6 components
3. Host-side helper tools used during the build (`-native` recipes)
4. Cross-toolchain and sysroot dependencies
5. Packaging and metadata tasks for the dependency closure

## Why The Task Count Looks So High

BitBake reports tasks, not recipes.
A single recipe usually expands into multiple tasks, for example:

- `do_fetch`
- `do_unpack`
- `do_patch`
- `do_configure`
- `do_compile`
- `do_install`
- `do_package`
- `do_populate_sysroot`

When that is multiplied across the full dependency graph, the total task count can easily reach the thousands.

## Why This Is Especially Noticeable For Qt Recipes

`medtech-clinician-ui` is a Qt-based application, so it pulls in a larger dependency tree than a small utility recipe.
That often includes:

1. `qtbase` and other Qt modules
2. Graphics and platform support libraries
3. Extra native tools needed during configuration and packaging

The first local build is usually the most expensive because downloads and sstate cache are still cold.

## What Matters More Than The Raw Task Count

A large task count is not automatically a problem.
More useful signals are:

1. Whether the build is progressing normally
2. Whether tasks are being restored from sstate
3. Whether the next build gets much faster
4. Whether the build ends in a real `ERROR`, not just warnings

## Practical Expectations

Typical pattern:

1. First build of `bitbake medtech-clinician-ui`: large dependency graph, many tasks
2. Second build of the same target: much faster because many tasks are cached
3. Small source change in the app recipe: only a smaller subset of tasks reruns

## Helpful Command

To inspect what the target depends on:

```bash
bitbake -g medtech-clinician-ui
```

This generates dependency graph files in the build directory and can help explain why a recipe pulls in so much work.
