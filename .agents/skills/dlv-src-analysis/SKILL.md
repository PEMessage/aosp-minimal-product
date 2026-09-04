---
name: dlv-src-analysis
description: Drive a dlv session through herdr to debug a running Go program, capture runtime variable values at each source line, and write a source-level analysis / blog that interleaves code, inlined runtime values, and reproducible dlv commands. Use for "source + runtime data structure evolution + reproducible debugging" documentation.
---

# Writing Source-Level Analysis with dlv + Herdr

Turn one debugging journey into a document: every source line gets the real value
of its variables the moment execution reaches it. Everything is driven through
herdr panes (load the herdr skill first) — no direct typing into terminals.

## 0. Prerequisites

- Target binary is debuggable (Go: built with `-N -l`; even better if the tool
  compiles itself with `-N -l` like microfactory does)
- A headless dlv is up: `dlv exec --headless --listen=:2345 <bin> -- <args>`
- Another pane runs `dlv connect localhost:2345` (single client: one at a time)

## 1. Identify the two panes

`herdr pane list` finds:
- `<build-pane>`: running `dlv exec` (shows "API server listening")
- `<dlv-pane>`: running `dlv connect`

## 2. Widen display first (do this before anything else)

```text
config max-string-len 300
config max-array-values 200
config max-variable-recurse 3
```
Defaults truncate strings to 64 chars, slices to 64 items, structs to 1 level.

## 3. Deploy breakpoints in execution order

- Entry: `b main.main` (or the target function)
- Main flow: one breakpoint per key function entry (`b <pkg>.(*T).Func`)
- Decision lines: try `b <file>:<line>`; if it reports "could not find
  statement", move to a neighboring line that has a statement
- Data-structure construction points and recursion/branch points get their own bp

## 4. Drive discipline: SERIAL — this is the core rule

**One command at a time; wait for the prompt before sending the next.**
Concurrent `pane send` calls interleave output and become unreadable.

```bash
herdr pane run <dlv-pane> "p os.Args"
herdr pane read <dlv-pane> --source recent-unwrapped --lines 30
```

- Breakpoints at function entry often can't show local vars yet (scope not
  established) → `n` twice, then `p`
- Function calls are rejected: `p flags.Arg(0)` errors with "function calls not
  allowed" → use fields/indexes instead
- Unexported fields ARE readable (dlv reads DWARF): `c.pkgs`, `p.hashResult`

## 5. What to sample

- Arguments / config / mappings: `os.Args`, post-flag-parse struct
- Data-structure growth: snapshot the collection length/content **before and
  after** an append/add — pairs make "evolution" visible
- Decision points: hash, `rebuild`, condition variables
- Pending commands: print an assembled-but-not-yet-run `cmd.Args` — great payoff
- Big graphs: `condition <bp#> 'p.Name == "main"'` stops only at the root and
  lets the traversal run free

## 6. Cross-check against disk

Memory values ↔ on-disk artifacts (hash files, trace, intermediates dirs) make
the analysis self-validating.

## 7. Finishing up

`c` until "has exited", then `quit` to release the connection (otherwise the
`dlv exec` build pane stays blocked). Build pipelines may spawn dlv repeatedly:
every new "API server listening" needs a reconnect-and-release
(connect → `c` to complete → `quit` after "has exited"; do NOT rely on
`quit` from a paused state — behavior differs by dlv version and may kill the
launched process).

## 8. Writing the document

- Strictly follow **execution order**; each section = source block (⭐ marks the
  current line) → dlv snapshot → take-away
- Inline values next to the corresponding source; do not stack a separate
  "runtime" chapter far away
- Append the full reproducible command list (config, breakpoints, step-by-step)
- If using trace timestamps: they include your debug pauses — pure compute only
  comes from B/E pairs that were never interrupted

## 9. Known pitfalls

| Pitfall | Fix |
|---|---|
| Locals unprintable at function entry | `n` twice, then `p` |
| `p someFunc(x)` rejected | use fields/indexes, or `call` |
| Line without statement won't break | pick a neighboring statement line |
| `next` may skip several consecutive statements | confirm position via `=>` marker |
| Variable unreadable at a bp (register liveness) | print at another line or `c` onward |
| Concurrent pane sends interleave output | serialize; wait for prompt |
| Headless accepts one client | don't open a 2nd connect; quit the old first |

## 10. Worked example in this repo

- Output: `docs/blog-microfactory-source-analysis.md` — this method applied to
  microfactory, including the full 11.4 ms cache-hit trace
- Enabling patch that wraps the target command line in headless dlv:
  `patchdb/code/build/blueprint/microfactory/microfactory.bash.patch`