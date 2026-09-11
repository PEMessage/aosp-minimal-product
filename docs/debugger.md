# Debugging the build

Three programs are worth stepping through: `ckati` (C++, the make replacement),
`soong_ui`/`soong_build` (Go) and `microfactory` (Go, the bootstrap builder).
Use gdb for ckati and dlv for the Go ones.

All of this is driven **inside the dev shell**. The repo's `nix develop` is a
`buildFHSEnv`; `nix develop --command <cmd>` does not reliably run commands
through it, so open the shell first and run the steps below from there:

```sh
nix develop
```

Inside the dev shell the repo's `bin/` is already on `PATH` (`flake.nix`), so
the examples below use bare `patchman`; outside it, use `bin/patchman`.

## Go dev tools (gopls + dlv)

The tree's prebuilt Go is go1.15.6 — too old for modern `go install
pkg@version`. `setup_go_tools.sh` builds the last compatible releases
(gopls v0.9.5, dlv v1.20.1) next to the prebuilt go binary, so a single PATH
entry covers go + gopls + dlv:

```sh
./scripts/setup_go_tools.sh                          # build + print PATH line
eval "$(./scripts/setup_go_tools.sh --print-path)"   # or just export it
```

## ckati (gdb)

Every ckati invocation (`dumpvars` x2, `kati build/package/cleanspec`) execs
`prebuilts/build-tools/linux-x86/bin/ckati`. The `CKATI_WAIT_USR2` hook in
`build/kati/src/main.cc` (patch `patchdb/code/build/kati/src/main.cc.patch`)
makes ckati wait before any makefile work until it receives `SIGUSR2`, so gdb
can attach without a race.

1. Apply the hook and the build script, then rebuild ckati with debug info and
   install it over the prebuilt. The stock binary is kept as
   `ckati.prebuilt.bak`; `repo sync prebuilts/build-tools` restores it.
   ```sh
   patchman apply code/build/kati   # main.cc hook (patch) + build.sh (copy)
   cd code/build/kati && bash build.sh   # stored build.sh is mode 0644
   ```
2. Stop at the hook and attach from a second terminal:
   ```sh
   # terminal 1: each ckati waits at startup
   cd code && source build/envsetup.sh && lunch lineage_minimum-eng
   CKATI_WAIT_USR2=1 m nothing

   # terminal 2
   bin/ckati-attach          # --loop to catch every invocation
   ```
3. `bin/ckati-attach` attaches gdb and releases the process with `SIGUSR2` when
   gdb exits. To keep gdb attached and let the build continue, use
   `(gdb) signal SIGUSR2` then `(gdb) continue` instead.

Why `SIGUSR2` and not `SIGSTOP`: soong_ui runs ckati as PID 1 inside an nsjail
PID namespace (`build/soong/ui/build/kati.go`), where the kernel silently drops
a self-delivered `SIGSTOP`. `SIGUSR2` has a handler, so it is delivered to
PID 1.

Never leave `CKATI_WAIT_USR2=1` set for unattended builds — every ckati run
blocks. `ckati --realpath` never waits.

### yama

With `kernel.yama.ptrace_scope=1` (many distros' default) a non-root tracer may
only attach to its own descendants. ckati's parent is soong_ui, not gdb, so the
attach is denied. Open it up once per boot, or run `bin/ckati-attach` under
sudo:

```sh
sudo sysctl kernel.yama.ptrace_scope=0
# NixOS: persist via boot.kernel.sysctl in flake.nix
```

## soong_ui and microfactory (dlv)

`build/soong/soong_ui.bash` and `build/blueprint/microfactory/microfactory.bash`
each have a patch adding a commented-out headless-dlv variant of their launch
command:

- `patchdb/code/build/soong/soong_ui.bash.patch`
- `patchdb/code/build/blueprint/microfactory/microfactory.bash.patch`

After a fresh `bootstrap.sh` these patches are **not applied** (`patchman
status`); a debugging session may have applied some of them. To debug:

1. Apply the patch, then uncomment the `dlv …` line and comment out the plain
   launch line in the file it patches:
   ```sh
   patchman apply code/build/soong            # or code/build/blueprint/microfactory
   ```
2. Run the build as usual; the program starts a headless dlv on `:2345`:
   ```sh
   m nothing
   ```
3. Connect and drive it (one client at a time; `quit` when done so the build
   can finish):
   ```sh
   dlv connect localhost:2345     # dlv comes from scripts/setup_go_tools.sh
   ```

`scripts/setup_go_tools.sh` installs a compatible `dlv` next to the prebuilt Go
(see "Go dev tools" above). To capture source-line values and turn the session
into a write-up, follow the `dlv-src-analysis` skill.

## envsetup (bashdb)

`build/make/envsetup.sh` has a patch (`patchdb/code/build/make/envsetup.sh.patch`)
that adds a commented-out `bashdb` variant of the `get_build_var()` call. Apply
it, then uncomment that line and comment out the original; point `BASHDB_BIN`,
`BASHDB_FIFO`, `BASHDB_FIFO_IN` and `BASHDB_LIB` at your bashdb install:

```sh
patchman apply code/build/make/envsetup.sh
```
