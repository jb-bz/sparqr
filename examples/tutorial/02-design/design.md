# Design: tutorial-cli-todo

> Stage 2 of SPARC+Design. Translates spec.md into a build-ready blueprint. Each section pins one decision so the implementation stage does not have to choose.

## 1. High-Level Architecture

One file: `tutorial.py`. Python 3.8+ stdlib only (`argparse`, `json`, `os`, `sys`, `pathlib`, `datetime`, `tempfile`). Executable as a script (`python3 tutorial.py ...`) and via a symlink on `$PATH` named `tutorial`. No third-party deps. Ships as a single Python file; the Bash+jq variant is dropped — Python is already cross-platform by definition, and shipping one artifact keeps the tutorial small.

Process model: one CLI invocation = one read-modify-write transaction on the JSON store. No daemon, no IPC, no concurrency primitives. Per spec, the user is warned not to run two invocations against the same store.

## 2. Module Structure

One file, top-level functions, no classes.

```
main()                      argparse setup, dispatches to cmd_* handlers
cmd_add(args)               validate text, make_id(), append, save_store(), print "[id] added: text"
cmd_list(args)              load_store(), filter (--done/--open/all), format each line, print
cmd_done(args)              load_store(), find by id, idempotent set done=true+completed_at, save
cmd_delete(args)            load_store(), find by id, pop, save
cmd_help(args)              print usage (argparse --help is acceptable too)

load_store(path) -> list    read JSON; missing file -> []; malformed -> err+exit 2
save_store(path, todos)     write to tmpfile mode 0600, os.replace() into place
find_todo(todos, id)        raise NoSuchId(id) if not present (caller catches)
make_id(todos)              max(existing ids, 0) + 1; ids start at 1, monotonic, stable across deletes
now_iso()                   datetime.now(timezone.utc).isoformat(timespec="seconds")
err(msg)                    print to stderr, sys.exit(2)
```

`NoSuchId` is a local exception. Exit codes: 0 success, 2 user error (bad input/missing id/usage), 3 I/O or corruption error.

## 3. Data Flow

```
argv
  -> argparse (subparsers: add|list|done|delete|help)
  -> cmd_* handler
       -> load_store(path)         [read JSON or []; abort on malformed]
       -> mutate in-memory list
       -> save_store(path, list)   [tmpfile 0600 + os.replace = atomic]
       -> print to stdout
errors -> stderr + non-zero exit
```

`--store PATH` global flag overrides the default location; the implementation stage will use it for the test harness.

## 4. JSON Schema

Default location: `~/.tutorial_todo.json`. Name was vetted against common dotfiles — no collision risk on a typical dev box.

```json
{
  "version": 1,
  "todos": [
    {
      "id": 1,
      "text": "buy milk",
      "done": false,
      "created_at": "2026-06-21T14:32:00+00:00",
      "completed_at": null
    }
  ]
}
```

Forward compatibility: on load, unknown top-level keys are preserved (we write back the parsed dict, not a re-projected one) and unknown per-todo keys are preserved on each todo dict. This is what makes a v1.0 reader safely load a v1.1 file with a `tags` field. The `version` field is informational in v1 — no migration logic.

## 5. CLI Surface

```
tutorial [--store PATH] <subcommand> ...

Subcommands:
  add <text>          Append a todo. <text> required, single positional.
  list [--done|--open]   Print todos, one per line. --done and --open mutually exclusive.
                         Default: show all (open + done).
  done <id>           Mark todo <id> done. Idempotent.
  delete <id>         Remove todo <id> by id (ids stable across deletes).
  help                Print usage block.

Global flags:
  --store PATH        Override JSON store location (testing + portability).
  -h, --help          Print usage and exit 0.

Output format (list):  [<id>] [<status>] <text>     where <status> is '✓' or ' '
Output format (other cmds):  short confirmation on stdout, e.g. "added todo 1: buy milk"
```

Usage block lists every subcommand with a one-line description (US-5).

## 6. Trade-offs and Resolved Open Questions

Resolved during this stage (was open in spec):

- **Empty list UX**: print a single `(no todos)` line on stdout, exit 0. Friendlier for first-run learners than silent output, and easier to assert in tests.
- **id 0**: rejected as `no todo with id 0`. Ids start at 1, assigned by `make_id()`.
- **argparse vs hand-rolled**: argparse. Worth the ~15 lines of boilerplate for `--help`, mutually-exclusive `--done/--open`, and typed errors.
- **Unreadable existing store**: refuse to start, print clear stderr message, exit 3. The spec's "must preserve permissions" only makes sense if we can read first; silent fallback would mask real problems.

Spike resolutions:

- `os.replace()` is atomic on APFS and ext4 (POSIX rename guarantee). Single-line tmp-write + replace is the write path. Document this assumption in code comments.
- Ship Python only. The Bash variant was a size hedge; Python at ~150 lines is small enough.
- `~/.tutorial_todo.json` does not collide with any well-known dotfile. Keep the name.
- Forward compat: yes — unknown keys are preserved on round-trip (resolved by writing the parsed dict back, not a re-projected one).
- IDs: monotonic integer. Human-typable from the CLI; UUIDs would be friction.

Out-of-scope items from the spec remain out-of-scope here (no tags, no edit, no sync, no completion files, English-only messages).
