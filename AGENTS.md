# AGENTS.md

## What this is

A **learning-oriented minimal LineageOS / AOSP build repository**. It does not
produce bootable images; its goal is to make the Android build system itself
understandable by reducing it to the smallest set of sources that can still
build end-to-end.

The project is tuned for **LineageOS 19.1 (Android 12)**, branch `lineage-19.1`.
It is distro-agnostic and pulls everything from Tsinghua mirrors.

## Core guidelines

1. **Zero source patches.** The LineageOS 19.1 build system works unpatched —
   prefer trimming the sync list or manifest over editing build sources.
2. **Minimal by construction.** Sync the fewest repos that reach the goal and
   justify every new one; never pull in a subsystem "just in case".
3. **The outer git repo is the source of truth.** Anything inside `code/` the
   synced tree does not own (source tweaks, product makefiles, local manifests)
   is managed with patchman under `patchdb/` and applied by `bootstrap.sh` —
   never edited into `code/` by hand. patchman is the git-like patch layer over
   the out-of-tree `repo` workspace, and its UX follows git
   (`docs/patchman.md`).
4. **`m nothing` stays green.** It is the build of record; re-run it after any
   change to the sync list, manifest, product, or `bootstrap.sh`.
5. **No secrets or mirror credentials.**

## Commands

The Android build needs an FHS filesystem layout (`/bin/pwd` etc.). On NixOS
this comes from the repo's dev shell, which is a `buildFHSEnv`: **open it
interactively** — `nix develop --command <cmd>` does not reliably run commands
through it.

```sh
# NixOS: open the FHS dev environment (interactive)
nix develop
```

If you cannot open an interactive shell yourself, ask the user to run
`nix develop` and then the commands below inside it.

Then run the core flow from **inside** that shell:

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

Debug hooks (gdb for ckati, dlv for soong_ui/microfactory) are in
`docs/debugger.md`; the general dlv workflow is the `dlv-src-analysis` skill.

## DeepClean

`code/` is a `repo` checkout, and the expensive part of a fresh
`./bootstrap.sh` is *downloading* the git object stores, not checking them out.
Those stores live in `code/.repo/` (`project-objects/`, `projects/`).  So the
cheap way back to a pristine tree is to keep `.repo/` and rebuild the working
tree from it: deleting `code/` entirely is the cleanest reset, this is the best
we can do without re-downloading everything.

`scripts/deep_clean.sh` is the delete half only: keep `code/.repo/`, drop every
other top-level entry there.  The re-sync is a separate step, so the two
compose:

```sh
scripts/deep_clean.sh            # drop the working tree, keep .repo/
scripts/deep_clean.sh --dry-run  # list what would be removed
scripts/deep_clean.sh -y         # no confirmation prompt

LOCAL_ONLY=1 ./bootstrap.sh      # rebuild from local objects, no network
```

It touches nothing under `.repo/` -- manifest and object stores are left as
they are.  It runs anywhere; the local sync needs the FHS dev shell
(`nix develop`).  `deep_clean.sh` refuses to delete without `-y` when stdin is
not a tty.

What survives and what comes back:

- **survives** — `code/.repo/` (objects, refs, manifests, `local_manifests/`).
- **re-checked-out** — every `repo` project working tree.
- **re-applied** by `bootstrap.sh` — the patchman copy entries (local manifest,
  `device/minimum/` product makefiles).
- **gone** — `code/out/`, so the next `m nothing` is a clean build.

If a project was never fully fetched, `--local-only` fails on it; fall back to a
normal `repo sync` for just that path.

## Patchman workflows

`bin/patchman` is the source of truth for anything inside `code/` the synced
tree does not own: source tweaks, the product makefiles and the local manifests.
It compares three trees (upstream `HEAD` / the working file / the stored entry)
and stores each file either as a unified diff (patch mode) or a whole-file copy
(copy mode). `bootstrap.sh` applies the device and local-manifest entries; the
debug tweaks are applied on demand.

```sh
bin/patchman status                 # every stored entry and its state
bin/patchman status -- .            # ... restricted to the cwd subtree
bin/patchman apply  [path ...]      # apply all, or a pathspec
bin/patchman reset  [path ...]      # revert (alias: checkout)
bin/patchman add [-m copy] <file>   # record the current file
bin/patchman cat <file>             # dump the stored entry
bin/patchman rm <file>              # stop tracking it
bin/patchman config ...             # read/write patchdb/config; set aliases
bin/patchman verify                 # consistency check (fsck)
```

`patchdb/config` is an optional INI file created on first `config` write; it
holds git-style aliases (`patchman config alias.st status` makes `patchman st`
work). Typical loop for a patchman-owned file: edit it in `code/`, then
`bin/patchman add [-m copy] <file>` to refresh the stored copy, then re-run the
build.

Full model, modes and path rules: `docs/patchman.md`.

## Reference

- `docs/repository.md` — layout, minimal repo set, product naming, key facts.
- `docs/debugger.md` — gdb/dlv debugging and Go dev tools.
- `docs/patchman.md` — patchman manual.
