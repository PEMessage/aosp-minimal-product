# Repository reference

Layout, repo set and product-naming rationale. Agent-facing rules are in
`AGENTS.md`.

## Layout

- `bootstrap.sh` — idempotent entry point. Repo-inits the tree, syncs the minimal
  repo set, applies zero-patch fixes, and runs the verification build.
- No standalone `device/` or `local_manifests/`: the `lineage_minimum` product
  (`lunch lineage_minimum-eng`; headless x86_64, no kernel/bootloader/images) and
  the local manifests live in the tree (`code/device/minimum/`,
  `code/.repo/local_manifests/`) as patchman copy entries.
- `scripts/make_manifest.py` — rewrites manifest remotes to Tsinghua AOSP.
  Shallow cloning comes from `repo init --depth 1` (bootstrap.sh pins the repo
  tool to `v2.66.1`, which applies that depth to every project without an
  explicit `clone-depth`), so no clone-depth injection is needed.
- `scripts/sync_paths.py` — extracts the minimal `build/` + curated `prebuilts/`
  paths from the manifest.
- `scripts/setup_go_tools.sh` — builds `gopls` + `dlv` with the tree's prebuilt
  Go; see `docs/debugger.md`.
- `bin/patchman` — git-like per-file patch manager for the out-of-tree `repo`
  workspace; see `docs/patchman.md`.
- `docs/` — design notes, debugging, patchman manual.
- `code/` — the actual AOSP tree (repo workspace), created by `bootstrap.sh`.

## Minimal repo set

The whole tree needed for a green `m nothing` is nine repos plus the device
files:

- `build/make`, `build/soong`, `build/blueprint` (build system core; `build/make`
  is linked into `build/` by the manifest, so `build/envsetup.sh` and
  `build/core/` are symlinks)
- `external/golang-protobuf` (soong_ui microfactory bootstrap)
- `external/starlark-go` (`build/make/tools/rbcrun` soong module)
- `build/kati` (ckati sources, added via `.repo/local_manifests/kati.xml`; a
  pinned SHA on a USTC remote — rationale in the file header)
- `prebuilts/build-tools`, `prebuilts/go/linux-x86`, `prebuilts/jdk/jdk11`,
  `prebuilts/clang/host/linux-x86`
  (ckati/ninja, go toolchain, Java 11; clang = the Android 12 toolchain used by
  `build/kati/build.sh` to rebuild ckati from source)
- `vendor/lineage` (required: `build/envsetup.sh` sources
  `vendor/lineage/build/envsetup.sh` unconditionally)

`sync_paths.py` also lists `build/bazel` and `build/pesto` (part of the
manifest's `build/` set, small, harmless).

## Why the product is `lineage_minimum`

The product is deliberately named `lineage_minimum`: the `lineage_` prefix is
what makes the build system pull in the vendor hooks, so `m nothing` exercises
the vendor-side logic instead of skipping it.

`build/envsetup.sh`'s `check_product` sets `LINEAGE_BUILD` from the prefix:

```sh
if (echo -n $1 | grep -q -e "^lineage_") ; then
    LINEAGE_BUILD=$(echo -n $1 | sed -e 's/^lineage_//g')
else
    LINEAGE_BUILD=
fi
```

`build/make/core/config.mk` only loads the vendor config when it is non-empty:

```makefile
ifneq ($(LINEAGE_BUILD),)
include vendor/lineage/config/BoardConfigLineage.mk
endif
```

`BoardConfigLineage.mk` then pulls in `config/BoardConfigKernel.mk` (kernel
build variables: `KERNEL_ARCH`, `KERNEL_MAKE_FLAGS`, ...) and
`config/BoardConfigSoong.mk`, which exports those variables to soong's
`lineageVarsPlugin` namespace (`SOONG_CONFIG_lineageVarsPlugin_*`).

Named `minimum`, `LINEAGE_BUILD` would be empty, the whole vendor hook chain
would be skipped, and `m nothing` would never exercise any vendor-side logic —
contradicting this repo's goal of exercising the vendor hooks.

The AndroidProducts mechanism also requires a same-named file:
`lunch lineage_minimum-eng` resolves the product name to a `<product>.mk` file
in the directories listed by `AndroidProducts.mk` (here the in-tree
`code/device/minimum/`, a patchman copy entry), so the makefile must be
`lineage_minimum.mk` with `PRODUCT_NAME := lineage_minimum`.

## Key facts

- `vendor/lineage/prebuilt` is quarantined out of the tree after sync: its
  `prebuilt_etc_xml` module (`sensitive_pn.xml`) ships a blob that is not in the
  repo, and soong builds actions for every module in the graph — the missing
  source file panics soong even for `m nothing`.
- `ALLOW_MISSING_DEPENDENCIES=true` is exported before building; many non-core
  repos are intentionally unsynced.
