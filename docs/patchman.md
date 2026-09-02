# patchman — per-file patch management

`bin/patchman` stashes and re-applies source tweaks made inside the
`code/` tree.  It is the small "quilt for this repo" tool: no extra
dependencies (just `git`, `diff` and GNU `patch`), all state is plain
files under `patchdb/`, which is tracked by the outer git repo.

## Model

The root is the directory that directly contains a `patchdb/` folder.
Every sub-command finds that root by walking up from the **current
directory** (git-style), so you never have to `cd` to the repo top:

```
<root>/
├── code/                      # the AOSP tree
│   └── build/blueprint/microfactory/microfactory.bash
└── patchdb/                   # git-tracked
    └── code/build/blueprint/microfactory/microfactory.bash.patch
```

Store paths mirror source paths relative to the root:

| source (relative to root)                        | stored patch                            |
|--------------------------------------------------|----------------------------------------|
| `code/build/blueprint/microfactory/microfactory.bash` | `patchdb/code/build/blueprint/microfactory/microfactory.bash.patch` |
| `code/build.sh`                                  | `patchdb/code/build.sh` (copy mode)    |

Two modes:

| mode    | storage                                | apply / reset                            |
|---------|----------------------------------------|------------------------------------------|
| `patch` | unified diff vs the owning git repo's HEAD (or `/dev/null` for brand-new files) | `patch -p1` forward / reverse |
| `copy`  | whole-file copy (+ `.orig` baseline if the source is git-tracked) | copy over target / restore `.orig` (or delete if the file was new) |

Mode is chosen automatically: patch mode for tracked, modified text files;
copy mode for untracked or binary files.  `-m patch|copy` forces it.

`patchdb/.patchman.json` records which mode + baseline commit each patch was
made against.

## Usage

```sh
# make gopls/dlv/patchman findable from anywhere (optional)
export PATH="$PWD/bin:$PATH"

# start using it: point PATCHDB anywhere, or just put patchdb/ where you want it
mkdir -p patchdb

# from anywhere under the root
cd code/build/blueprint/microfactory
patchman add microfactory.bash        # diff vs build/blueprint HEAD
patchman add --mode copy build.sh     # whole-file copy

patchman status                        # every stored patch: applied? not applied?
patchman status code/build             # only the subtree

patchman apply                          # apply everything
patchman apply code/build/blueprint     # apply a subtree (or a single file path)
patchman reset                          # unapply everything (restore git state)
patchman reset code/build.sh            # (checkout is an alias of reset)

patchman rm code/build.sh               # stop tracking a patch
patchman root                           # print detected root
```

Notes

* `apply`/`reset` accept a directory **or a single stored file path**.
* `reset` is aliased as `checkout` for muscle-memory convenience.
* `PATCHDB` env var overrides the walk-up search.
* `status` uses `patch --dry-run` (with `-N`) so it never writes `.rej`
  files and correctly distinguishes applied / not applied / conflict.
* `patchman` itself needs no FHS container: it only shells out to `git`,
  `diff` and `patch`.