# AGENTS.md

## What this is

A **learning-oriented minimal LineageOS / AOSP build repository**. It does not
produce bootable images; its goal is to make the Android build system itself
understandable by reducing it to the smallest set of sources that can still
build end-to-end.

The project is tuned for **LineageOS 19.1 (Android 12)**, branch `lineage-19.1`.
It is distro-agnostic and pulls everything from Tsinghua mirrors (China-friendly).

## Core guidelines

1. **Zero source patches.** The LineageOS 19.1 build system works unpatched —
   prefer trimming the sync list or manifest over editing build sources.
2. **Minimal by construction.** Sync the fewest repos that reach the goal and
   justify every new one; never pull in a subsystem "just in case".
3. **The outer git repo is the source of truth.** Anything inside `code/` the
   synced tree does not own (source tweaks, product makefiles, local manifests)
   is managed with patchman under `patchdb/` and applied by `bootstrap.sh` —
   never edited into `code/` by hand.
4. **`m nothing` stays green.** It is the build of record; re-run it after any
   change to the sync list, manifest, product, or `bootstrap.sh`.
5. **No secrets or mirror credentials.**

## Layout

- `bootstrap.sh` — idempotent entry point. Repo-inits the tree, syncs only the
  minimal set of repos needed for `m nothing`, applies zero-patch fixes, and
  runs the verification build.
- No standalone `device/` or `local_manifests/`: the `lineage_minimum` product
  (`lunch lineage_minimum-eng`; headless x86_64, no kernel/bootloader/images)
  and the local manifests live in the tree (`code/device/minimum/`,
  `code/.repo/local_manifests/`) as patchman copy entries.
- `scripts/make_manifest.py` — rewrites manifest remotes to Tsinghua AOSP.
  Shallow cloning is handled by `repo init --depth 1` (bootstrap.sh pins the
  repo tool to tag `v2.66.1`, which applies that depth to every project lacking
  an explicit `clone-depth`), so no clone-depth injection is needed.
- `scripts/sync_paths.py` — extracts the minimal `build/` + curated `prebuilts/`
  paths from the manifest.
- `scripts/setup_go_tools.sh` — builds `gopls` + `dlv` with the tree's prebuilt
  Go (go1.15.6) and prints the PATH entry to add.
- `bin/patchman` — per-file patch manager (details in `docs/patchman.md`). It
  owns every in-tree tweak plus the product makefiles and local manifests as
  `patchdb/code/...` entries, which `bootstrap.sh` applies.
- `docs/` — notes on design decisions (e.g. `docs/why-lineage_minimum.md`).
- `code/` — the actual AOSP tree (repo workspace), created by `bootstrap.sh`.

## Commands

The Android build needs an FHS filesystem layout (`/bin/pwd` etc.). On NixOS
this comes from the repo's dev shell — enter it before anything else:

```sh
# NixOS: enter the FHS dev environment
#   interactive (drop into a shell):
nix develop
#   non-interactive (run one command inside it):
nix develop --command ./bootstrap.sh
```

Once inside the FHS environment:

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

### Go dev tools (gopls + dlv)

The tree's prebuilt Go is go1.15.6 (too old to run modern `go install
pkg@version`). `setup_go_tools.sh` builds the last compatible releases into the
same dir as the prebuilt go binary, so one PATH entry covers go + gopls + dlv:

```sh
# Build + print the PATH line (gopls v0.9.5, dlv v1.20.1)
./scripts/setup_go_tools.sh

# Or add the PATH entry to your shell:
eval "$(./scripts/setup_go_tools.sh --print-path)"
```

### Debugging ckati (gdb)

Every ckati invocation (dumpvars x2, kati build/package/cleanspec) execs
`prebuilts/build-tools/linux-x86/bin/ckati`. A `CKATI_WAIT_USR2` hook in
`build/kati/src/main.cc` (managed as
`patchdb/code/build/kati/src/main.cc.patch`) makes ckati wait before any
makefile work until it receives SIGUSR2 when that env var is set;
`build/kati/build.sh` rebuilds ckati with debug info and installs it over
the prebuilt (stock copy kept as `ckati.prebuilt.bak`; `repo sync
prebuilts/build-tools` restores it).

Why SIGUSR2: soong_ui runs kati as PID 1 inside an nsjail PID namespace
(`build/soong/ui/build/kati.go`), where SIGSTOP is silently dropped. SIGUSR2
has a handler, so it is delivered even to PID 1.

```sh
# terminal 1 (FHS shell):
cd code/build/kati && ./build.sh          # rebuild + install debug ckati
cd ../.. && source build/envsetup.sh && lunch lineage_minimum-eng
CKATI_WAIT_USR2=1 m nothing                # each ckati waits at startup

# terminal 2:
bin/ckati-attach          # attach to the waiting ckati (--loop to catch them all)
```

To keep gdb attached and continue past the hook, use `(gdb) signal SIGUSR2`
then `(gdb) continue`; otherwise `bin/ckati-attach` sends SIGUSR2 for you
after gdb exits.

yama: non-root attach is denied while `kernel.yama.ptrace_scope=1`; run
`sudo sysctl kernel.yama.ptrace_scope=0` once per boot (persist via
`boot.kernel.sysctl` in flake.nix) or run `bin/ckati-attach` under sudo.
Never leave `CKATI_WAIT_USR2=1` set for unattended builds — every ckati run
will block. `ckati --realpath` never waits.

## Minimal repo set

The entire tree needed for a green `m nothing` is only nine repos plus the
device files:

- `build/make`, `build/soong`, `build/blueprint` (build system core; `build/make`
  is linked into `build/` by the manifest, so `build/envsetup.sh` and
  `build/core/` are symlinks)
- `external/golang-protobuf` (soong_ui microfactory bootstrap)
- `external/starlark-go` (`build/make/tools/rbcrun` soong module)
- `build/kati` (ckati sources, added via `.repo/local_manifests/kati.xml`; a
  pinned SHA on a USTC remote — rationale in the file header)
- `prebuilts/build-tools`, `prebuilts/go/linux-x86`, `prebuilts/jdk/jdk11`,
  `prebuilts/clang/host/linux-x86`
  (ckati/ninja, go toolchain, Java 11; clang = the Android 12 toolchain used
  by `build/kati/build.sh` to rebuild ckati from source)
- `vendor/lineage` (required: `build/envsetup.sh` sources
  `vendor/lineage/build/envsetup.sh` unconditionally)

`sync_paths.py` also lists `build/bazel` and `build/pesto` (part of the
manifest's `build/` set, small, harmless).

## Key facts for agents

- The product is `lineage_minimum`, not `minimum`: the `lineage_` prefix
  activates the vendor hooks. See `docs/why-lineage_minimum.md`.
- `vendor/lineage/prebuilt` is quarantined out of the tree after sync: its
  `prebuilt_etc_xml` module (`sensitive_pn.xml`) ships a blob that is not in the
  repo, and soong builds actions for every module in the graph — the missing
  source file panics soong even for `m nothing`.
- `ALLOW_MISSING_DEPENDENCIES=true` is exported before building; many non-core
  repos are intentionally unsynced.
