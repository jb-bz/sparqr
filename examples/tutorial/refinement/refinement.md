# Refinement: tutorial-cli-todo

> Stage 5 of SPARC+Design. Turns architecture into a working implementation. This document captures the choices made during refinement; the code itself is in `src/tutorial.py`.

## Provenance note

The `src/tutorial.py` file in this directory is hand-written from
the LLM's reasoning captured in `_stage-runs/refinement.log`. The
LLM (MiniMax M3 with the sparc-refinement profile) read the spec,
design, pseudocode, and architecture artifacts, generated ~1200
lines of internal reasoning and design notes, then hung on file
generation (5+ minutes, 0% CPU). The code below is hand-written,
following the LLM's exact reasoning trace, and verified
end-to-end via a smoke test (see the README "Smoke test" section).

The full 1236-line LLM reasoning trace is preserved in
`_stage-runs/refinement.log` for anyone who wants to see what
the LLM was thinking about (TOCTOU race conditions on chmod,
argparse error handling edge cases, the `open` Python builtin
shadowing, etc.).

## What was pinned during refinement

The LLM's reasoning surfaced 11 specific decisions that needed
to be made. Each is captured here for the next stage (completion)
to consume.

### 1. argparse subparser `add_help=False` on every subparser

Each subparser (`add`, `list`, `done`, `delete`, `help`) sets
`add_help=False` so the top-level `tutorial --help` works uniformly
and so the spec's exact "unknown command: X" formatting is preserved
when the pre-validation catches an unknown subcommand. The spec
doesn't require `tutorial add --help`, so the subcommand-level help
can be omitted without losing functionality.

### 2. `dest="open_"` was a mistake

argparse allows `dest="open_"` to avoid shadowing the `open` builtin
(so `args.open_` is the parsed value). But the spec US-2 acceptance
criteria use `args.open` (without the trailing underscore). The
correct fix: rename the parameter to `--open` (no `dest`), and
reference it as `args.open` in the code. This is the only place the
LLM's first draft had a real bug, and it's fixed in the final
implementation.

### 3. `find_todo` rejects id 0 and negative ids

`args.tid` from argparse with `type=int` can be 0 or negative if
the user types `tutorial done 0`. The spec doesn't explicitly call
this out, but the design stage (Section 5) says "id 0 rejected as
`no todo with id 0`. Ids start at 1, assigned by `make_id()`." So
`find_todo` raises `NoSuchId(0)` which becomes
`err("no todo with id 0", 2)`. Same error path as "id not found"
— both are user errors (exit 2).

### 4. Mode 0600 on first write, preserve on subsequent

The spec US-1 says: "must preserve permissions on subsequent writes".
The implementation:
- First write: no existing file → `existing_mode = 0o600` (secure default).
- Subsequent writes: `os.stat(path).st_mode & 0o777` to preserve.

The LLM's reasoning flagged a TOCTOU race here: if the file is deleted
between `os.stat()` and `os.replace()`, the chmod might clobber a
newly-created file's permissions. The implementation uses `try/except
FileNotFoundError` around the stat, and the chmod on the temp file
operates on the temp file, not the path. So the race window is small
and the worst case is "we set 0600 on a new file the user just
created" — which is what the spec wants anyway.

### 5. Idempotent `done` doesn't update `completed_at`

Spec US-3 says: "If found and already `done: true`, ... exit 0 (idempotent;
do NOT update `completed_at`)." The implementation explicitly skips
the `t["completed_at"] = now_iso()` line on the already-done path.
This matters because `now_iso()` is the current time, and re-stamping
it would lose the original completion time.

### 6. `args.open` shadows Python builtin `open`

In Python, `open` is a builtin function. If we used
`args = parser.parse_args()` and then `open(path)`, the `open` in
`args.open` would shadow the builtin only inside the parser's
namespace — actually no, `args.open` is an attribute access, not a
local rebinding. So `args.open` and `open(path)` don't conflict in
practice. The original `dest="open_"` was unnecessary.

The fix in the final implementation: drop `dest="open_"` and use
`args.open` directly. Same behavior, less confusion.

### 7. TOCTOU on `os.replace` is safe by construction

The LLM flagged: between the temp file creation and the `os.replace`
call, the user could replace the target file with a symlink pointing
elsewhere. The `os.replace` would follow the symlink and replace
its target. The mitigation: `os.replace` on a symlink replaces the
symlink itself, not its target, in POSIX. So this is safe. The
implementation doesn't need extra checks.

### 8. JSON `sort_keys=True` for deterministic output

The implementation uses `json.dump(..., sort_keys=True)`. This makes
the file's bytes deterministic across runs (helpful for diffs and
tests). The spec doesn't pin this either way, but the design stage's
"forward compat: write back the parsed dict" is satisfied either
way. We choose deterministic output.

### 9. Empty list prints `(no todos)` on stdout, exit 0

Spec US-2: "Given there are zero todos, When I run `tutorial list`,
Then the command exits 0 and prints nothing on stdout (or a single
'(no todos)' line — pick one and document it)." The implementation
chooses `(no todos)`. This is friendlier for first-run learners than
silent output, and easier to assert in tests.

### 10. `tutorial help` exits 0, prints to stdout

Spec US-5: "Given any invocation, When I run `tutorial` or
`tutorial help` or `tutorial --help` or `tutorial -h`, Then stdout
prints a usage block listing all subcommands with a one-line
description of each, and the command exits 0." The implementation
handles all four invocations in the `main` function's first
pre-check, before argparse sees anything. No need for argparse's
own `--help` (which is why `add_help=False` is set).

### 11. Unknown subcommand prints to stderr, usage to stdout

The spec's style is consistent across US-5: stdout is for output,
stderr is for errors. The implementation's pre-validation:
- Prints `unknown command: <name>` to **stderr**.
- Prints the full usage block to **stdout**.
- Exits 2.

This matches the spec's "user error" convention.

## Out-of-scope items (carried over from architecture)

- Tags / labels (US-1 is satisfied; no `tag add` command).
- Edit (in-place text modification; users delete + re-add for now).
- Sync (cloud, multi-device).
- Config file (no `--config` flag; use the default `~/.tutorial_todo.json`).
- Bash variant (Python only; ~297 lines is small enough for a single file).
- Locking (concurrent invocations are last-writer-wins; documented in README).
- Tests for `tutorial.py` itself (lives in `examples/`, not `tests/`).

## What's verified

The implementation has been smoke-tested end-to-end against a
temporary store (`/tmp/smoke-$$.json`). The following commands
were exercised and behave per spec:

| Command | Result | Spec ref |
|---|---|---|
| `add "buy milk"` | `added todo 1: buy milk` | US-1 |
| `add "walk dog"` | `added todo 2: walk dog` | US-1 |
| `list` | both todos shown, formatted `[id] [ ] text` | US-2 |
| `done 1` | `marked todo 1 done`, sets `completed_at` | US-3 |
| `list --done` | only the done todo | US-2 |
| `list --open` | only the open todo | US-2 |
| `delete 2` | `deleted todo 2`, removed from list | US-4 |
| `done 1` (idempotent) | `todo 1 already done`, exit 0 | US-3 |
| `done 99` (bad id) | stderr `no todo with id 99`, exit 2 | US-3 |
| `add ""` (empty text) | stderr `text required`, exit 2 | US-1 |
| `frobnicate` (unknown cmd) | stderr `unknown command: frobnicate`, usage to stdout, exit 2 | US-5 |
| `--store X frobnicate` | same (with --store flag walking) | US-5 |

The store file after a full run is well-formed JSON with
`{version: 1, todos: [...]}` and all required fields.

## What's not tested

- Concurrent invocations (the spec accepts last-writer-wins; the README
  warns users not to run two at once).
- Malformed store recovery (the spec says exit 3 without overwriting;
  the implementation does this, but the smoke test doesn't verify it
  end-to-end).
- Filesystem-specific edge cases (network filesystems, noatime, etc.).

The completion stage should add a few unit tests for the pure
functions (`make_id`, `find_todo`, `now_iso`) — these don't depend
on filesystem or argparse and are easy to test in isolation.
