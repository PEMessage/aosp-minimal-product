# patchman — per-file patch management

`bin/patchman` stashes and re-applies source tweaks made inside the
`code/` tree.  It is the small "quilt for this repo" tool: no extra
dependencies (just `git`, `diff` and GNU `patch`), all state is plain
files under `patchdb/`, which is tracked by the outer git repo.

## Model: three trees (git-style)

Like `git status`, every decision is a **three-way comparison** between

* **pristine** — the upstream baseline: the owning git repo's
  `HEAD:<file>` content (or nothing, for files git never tracked)
* **actual**   — the file in the working tree right now
* **stored**   — what is recorded under `patchdb/`

From that comparison fall out the three states:

| state        | meaning                              |
|--------------|--------------------------------------|
| `applied`    | stored matches actual (patch removes cleanly) |
| `not applied`| actual matches pristine              |
| `conflict`   | actual matches neither               |

The root is the directory that directly contains a `patchdb/` folder.
Every sub-command finds that root by walking up from the **current
directory** (git-style), so you never have to `cd` to the repo top:

```
<root>/
├── code/                      # the AOSP tree
│   └── build/blueprint/microfactory/microfactory.bash
└── patchdb/                   # git-tracked
    ├── code/build/blueprint/microfactory/microfactory.bash.patch
    └── .orig/...              # baseline copies for copy-mode entries
```

Store paths mirror source paths relative to the root:

| source (relative to root)                        | stored patch                            |
|--------------------------------------------------|----------------------------------------|
| `code/build/blueprint/microfactory/microfactory.bash` | `patchdb/code/build/blueprint/microfactory/microfactory.bash.patch` |
| `code/build.sh`                                  | `patchdb/code/build.sh` (copy mode)    |
| `code/device/minimum/AndroidProducts.mk`         | `patchdb/code/device/minimum/AndroidProducts.mk` (copy mode) |
| `code/.repo/local_manifests/kati.xml`            | `patchdb/code/.repo/local_manifests/kati.xml` (copy mode) |

## Two modes

| mode    | storage                                | apply / reset                            |
|---------|----------------------------------------|------------------------------------------|
| `patch` | **git-style** unified diff vs the owning repo's HEAD (or `/dev/null` for brand-new files) | GNU `patch -p1` forward / reverse |
| `copy`  | whole-file copy (+ `.orig` baseline if the source is git-tracked) | copy over target / restore `.orig` (or delete if the file was new) |

Mode is chosen automatically: patch mode for tracked, modified text files;
copy mode for untracked or binary files.  `-m patch|copy` forces it.

Two details worth knowing:

* Patch files use the `git diff` header format (`diff --git`, an `index
  h1..h2 mode` line, `new file mode` for brand-new files).  GNU `patch`
  remains the apply engine, and because the header is git-style the same
  file can be cross-checked with `git apply --check` (after relabelling
  paths to be repo-relative).
* `patchman add` stamps the patch with a `# base: <sha>` comment recording
  the git HEAD it was generated against.  No JSON manifest is kept: the
  directory layout is the whole state, and a patch's mode is derivable
  from whether the stored file ends in `.patch`.

## Config and aliases

`patchdb/config` is an INI file (Python's `configparser`) laid out like a
small `.git/config`: `section.key` names, with `[alias]` understood by
patchman.  It is **created on first use**, is never treated as a stored entry,
and is reported by `verify` if it cannot be parsed.

```sh
patchman config alias.st status                    # set
patchman config alias.s  'status --porcelain'
patchman config alias.co reset
patchman config alias.who '!git log -1 --oneline'  # ! runs a shell command

patchman config alias.st        # get one value (exit 1 if unset)
patchman config alias           # list one section
patchman config --list          # list everything: name=value
patchman config --unset alias.co
patchman config -e              # edit in $EDITOR / core.editor
```

Aliases expand exactly like git's: the leading word is replaced by the alias
body and the remaining arguments are appended.

```sh
patchman s -- .        # == patchman status --porcelain -- .
patchman who           # runs `git log -1 --oneline`
```

A `!` body runs through `sh -c '<body> "$@"'`, so `$1`, `$@`, ... see the
extra arguments.  Cycles (`alias.a = b`, `alias.b = a`) are reported, never
recursed.  Edit-time editor resolution is `$PATCHMAN_EDITOR`, then
`core.editor`, then `$VISUAL`, `$EDITOR`, finally `vi`.

## What this repo stores

Both modes are in use here:

* **patch mode** — debug tweaks applied on top of the synced AOSP sources:
  `code/build/kati/src/main.cc` (CKATI_WAIT_USR2), the envsetup bashdb line,
  the soong_ui dlv hook and the microfactory dlv hook.
* **copy mode** — content with no upstream baseline inside the tree, so it has
  nowhere to diff against. There is **no standalone `device/` or
  `local_manifests/` directory** in this repo; instead these are real files in
  the tree, owned by patchman as whole-file copies:
  * the product makefiles — `code/device/minimum/` (`AndroidProducts.mk`,
    `lineage_minimum.mk`, `BoardConfig.mk`), and
  * the repo local manifests — `code/.repo/local_manifests/kati.xml`.

`bootstrap.sh` materialises both with `patchman apply code/device/minimum` and
`patchman apply code/.repo/local_manifests` (see `install_local_manifests` /
`setup_product`). To edit them, change the file in the tree and re-run
`patchman add --mode copy <file>` to refresh the stored copy.

## Usage

```sh
# make gopls/dlv/patchman findable from anywhere (optional)
export PATH="$PWD/bin:$PATH"

# from anywhere under the root
cd code/build/blueprint/microfactory
patchman add microfactory.bash        # diff vs build/blueprint HEAD
patchman add --mode copy build.sh     # whole-file copy

patchman status                        # human table: every stored patch's state
patchman status --porcelain            # machine-readable: rel<TAB>state
patchman status -- .                   # only the current directory's subtree
patchman status -- code/build code/device/minimum   # several pathspecs
patchman cat envsetup.sh               # dump a stored patch to stdout

patchman apply                          # apply everything
patchman apply code/build/blueprint     # apply a subtree (or a single file path)
patchman apply -- .                     # apply the cwd subtree only
patchman reset                          # unapply everything (restore git state)
patchman reset code/build.sh            # (checkout is an alias of reset)

patchman config alias.st status         # store an alias (see Config and aliases)
patchman st --porcelain                 # ... and use it
patchman verify                         # fsck-style consistency check of patchdb
patchman rm code/build.sh               # stop tracking a patch
patchman root                           # print detected root
```

Notes

* `apply`/`reset`/`status` accept zero or more **pathspecs**: directories or
  single stored files.  Paths are resolved from the current directory, and a
  rooted lookup like `status patchdb/code/build` is accepted too.  Use `--` to
  separate pathspecs from options (`status --porcelain -- .`), exactly as with
  git; `.` means the current directory's subtree.
* `status` uses `patch --dry-run` (with `-N`) so it never writes `.rej`
  files and correctly distinguishes applied / not applied / conflict.  A
  tracked copy-mode entry whose target still equals its `.orig` baseline is
  "not applied", not "conflict".
* `verify` checks for orphan `.orig` baselines, unparseable patch files,
  stored entries whose source file is gone, a malformed `patchdb/config`, and
  any leftover legacy `.patchman.json`; it exits non-zero on any problem.
* `patchman` itself needs no FHS container: it only shells out to `git`,
  `diff` and `patch`.