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

## Command layers (git-style porcelain / plumbing)

`patchman --help` renders the subcommands in two groups, mirroring how
`git help` categorizes its commands:

* **porcelain** — user-facing actions that compose the plumbing:
  `add`, `status` (human table), `apply`, `reset`, `rm`
* **plumbing** — scriptable / diagnostic primitives:
  `cat` (dump a stored entry), `verify` (consistency check), `root`
  (discovery query); plus `status --porcelain` for machine-readable output,
  the same split git makes between `git status` and `git status --porcelain`

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
patchman cat envsetup.sh               # dump a stored patch to stdout

patchman apply                          # apply everything
patchman apply code/build/blueprint     # apply a subtree (or a single file path)
patchman reset                          # unapply everything (restore git state)
patchman reset code/build.sh            # (checkout is an alias of reset)

patchman verify                         # fsck-style consistency check of patchdb
patchman rm code/build.sh               # stop tracking a patch
patchman root                           # print detected root
```

Notes

* `apply`/`reset`/`status` accept a directory **or a single stored
  file path**; all paths are resolved from the current directory, and a
  rooted lookup like `status patchdb/code/build` is accepted too.
* `status --porcelain` is the machine-readable form (git's
  `status --porcelain` analogue): one `rel<TAB>state` line per entry,
  suitable for scripting.
* `reset` is aliased as `checkout` for muscle-memory convenience.
* `$PATCHDB` (git's `$GIT_DIR` analogue) overrides the walk-up search:
  point it at a `patchdb/` directory and the root is its parent.
* `status` uses `patch --dry-run` (with `-N`) so it never writes `.rej`
  files and correctly distinguishes applied / not applied / conflict.
* `verify` checks for orphan `.orig` baselines, unparseable patch files,
  stored entries whose source file is gone, and any leftover legacy
  `.patchman.json`; it exits non-zero on any problem.
* `patchman` itself needs no FHS container: it only shells out to `git`,
  `diff` and `patch`.