# AGENTS.md

## What this is

A **learning-oriented minimal LineageOS / AOSP build repository**. It does not
produce bootable images; its goal is to make the Android build system itself
understandable by reducing it to the smallest set of sources that can still
build end-to-end.

The project is tuned for **LineageOS 19.1 (Android 12)**, branch `lineage-19.1`.
It is distro-agnostic and pulls everything from Tsinghua mirrors (China-friendly).

## Layout

- `bootstrap.sh` — idempotent entry point. Repo-inits the tree, syncs only the
  minimal set of repos needed for `m nothing`, applies zero-patch fixes, and
  runs the verification build.
- `device/minimum/` — the custom `lineage_minimum` product
  (`lunch lineage_minimum-eng`). A headless x86_64 board: no kernel, no
  bootloader, no images.
- `scripts/make_manifest.py` — rewrites manifest remotes to Tsinghua AOSP and
  injects `clone-depth="1"` on every project (modern `repo` ignores
  `repo init --depth`, and full-history syncs of e.g. `prebuilts/build-tools`
  are far too slow over a CN mirror).
- `scripts/sync_paths.py` — extracts the minimal `build/` + curated `prebuilts/`
  paths from the manifest.
- `code/` — the actual AOSP tree (repo workspace), created by `bootstrap.sh`.

## Commands

```sh
# Build everything (idempotent; safe to re-run)
./bootstrap.sh

# Or manually inside the tree
cd code
source build/envsetup.sh
lunch lineage_minimum-eng
m nothing
```

`m nothing` is the build target of record — it exercises the full build system
(envsetup, soong bootstrap, kati, ninja, vendor hooks) without producing device
artifacts.

## Minimal repo set

The entire tree needed for a green `m nothing` is only nine repos plus the
device files:

- `build/make`, `build/soong`, `build/blueprint` (build system core; `build/make`
  is linked into `build/` by the manifest, so `build/envsetup.sh` and
  `build/core/` are symlinks)
- `external/golang-protobuf` (soong_ui microfactory bootstrap)
- `external/starlark-go` (`build/make/tools/rbcrun` soong module)
- `prebuilts/build-tools`, `prebuilts/go/linux-x86`, `prebuilts/jdk/jdk11`
  (ckati/ninja, go toolchain, Java 11)
- `vendor/lineage` (required: `build/envsetup.sh` sources
  `vendor/lineage/build/envsetup.sh` unconditionally)

`sync_paths.py` also lists `build/bazel` and `build/pesto` (part of the
manifest's `build/` set, small, harmless).

## Key facts for agents

- The product is named `lineage_minimum`, not `minimum`. The `lineage_` prefix
  sets `LINEAGE_BUILD`, which makes `build/make/core/config.mk` pull in
  `vendor/lineage/config/BoardConfigLineage.mk` (kernel + soong config hooks).
  `BoardConfigSoong.mk` auto-exports the `SOONG_CONFIG_lineageVarsPlugin_*`
  kernel variables, so `BoardConfig.mk` needs no `SOONG_CONFIG` block of its own.
- `vendor/lineage/prebuilt` is quarantined out of the tree after sync: its
  `prebuilt_etc_xml` module (`sensitive_pn.xml`) ships a blob that is not in the
  repo, and soong builds actions for every module in the graph — the missing
  source file panics soong even for `m nothing`.
- `ALLOW_MISSING_DEPENDENCIES=true` is exported before building; many non-core
  repos are intentionally unsynced.
- The build is verified green with `lunch lineage_minimum-eng && m nothing`.

## Conventions

- Keep patches at zero — the LineageOS 19.1 build system works unpatched.
  Prefer trimming the manifest/sync list over editing build sources.
- Never introduce secrets or mirror credentials.
