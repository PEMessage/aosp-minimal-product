# AGENTS.md

## What this is

A **learning-oriented minimal LineageOS / AOSP build repository**. It does not
produce bootable images; its goal is to make the Android build system itself
understandable by reducing it to the smallest set of sources that can still
build end-to-end.

The project is tuned for **LineageOS 16.0 (Android 9)**, branch `lineage-16.0`.
It is distro-agnostic and pulls everything from Tsinghua mirrors (China-friendly).

## Layout

- `bootstrap.sh` — idempotent entry point. Repo-inits the tree, syncs only the
  minimal set of repos needed for `m nothing`, applies zero-patch fixes, and
  runs the verification build.
- `device/minimum/` — the custom `minimum` product (`lunch minimum-eng`).
  A headless x86_64 board: no kernel, no bootloader, no images.
- `scripts/make_manifest.py` — rewrites manifest remotes to Tsinghua AOSP.
- `scripts/sync_paths.py` — extracts the minimal `build/` + `prebuilts/` repo
  paths from the manifest.
- `code/` — the actual AOSP tree (repo workspace), created by `bootstrap.sh`.

## Commands

```sh
# Build everything (idempotent; safe to re-run)
./bootstrap.sh

# Or manually inside the tree
cd code
source build/envsetup.sh
lunch minimum-eng
m nothing
```

`m nothing` is the build target of record — it exercises the full build system
(envsetup, kati, soong, vendor hooks) without producing device artifacts.

## Key facts for agents

- `vendor/lineage` is **required**: `build/make/envsetup.sh` sources
  `vendor/lineage/build/envsetup.sh` unconditionally. It is listed in
  `bootstrap.sh` `sync_deps` (do not remove).
- `BoardConfig.mk` intentionally declares **no kernel/bootloader** and sets
  empty `lineageVarsPlugin` SOONG config values to satisfy
  `vendor/lineage`'s `lineage_generator` module.
- `ALLOW_MISSING_DEPENDENCIES=true` is exported before building; many non-core
  repos are intentionally unsynced.
- The build is verified green with `lunch minimum-eng && m nothing`.

## Conventions

- Keep patches at zero — the LineageOS 16.0 build system works unpatched.
  Prefer trimming the manifest/sync list over editing build sources.
- Never introduce secrets or mirror credentials.
