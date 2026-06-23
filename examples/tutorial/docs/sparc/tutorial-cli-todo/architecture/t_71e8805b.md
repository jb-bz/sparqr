# Architecture: tutorial-cli-todo

> Stage 4 of SPARC+Design. Translates pseudocode's "what" into the system's "how" — components, data model, data flow, and failure modes. The Refinement stage will then turn this into actual code.

## Provenance note

This artifact was hand-written from the LLM's reasoning captured in
`_stage-runs/architecture.log`. The LLM (MiniMax M3 with the
sparc-architecture profile) read the spec, design, and pseudocode
artifacts successfully, produced a clear structure plan ("Components
= logical layers of tutorial.py, API Contracts = CLI subcommand
contracts, Data Models = JSON schema, Data Flow = one per user story,
Failure Modes = I/O + parse + permissions"), and then hung during
file generation (5+ minutes, no progress). The orchestrator's
sparc-architecture skill template (150 lines) is significantly
larger than the sparc-pseudocode template (69 lines), and the
longer generation appears to be a model-side bottleneck rather
than a bug. The hand-written file below follows the LLM's exact
structure plan and pins every open question from pseudocode.

## 1. Components (logical layers of tutorial.py)

The single 150-line Python file is organized top-to-bottom as
five logical layers. No classes; just module-level functions.

| Layer | Functions | Responsibility |
|---|---|---|
| 1. CLI entry | `main()`, `cmd_add`, `cmd_list`, `cmd_done`, `cmd_delete`, `cmd_help` | argparse setup, dispatch |
| 2. Domain | `make_id`, `now_iso`, `find_todo`, `NoSuchId` (exception) | Pure business logic, no I/O |
| 3. Storage | `load_store`, `save_store` | JSON read/write with atomicity guarantees |
| 4. Errors | `err(msg, code)` | stderr print + exit code (2 = user, 3 = I/O) |
| 5. Bootstrap | `if __name__ == "__main__": main()` | Single entry point |

Call direction is strictly downward: CLI calls Domain; CLI and
Domain call Storage. Storage never calls Domain or CLI. Errors
are called from any layer.

## 2. Data Model

The store is a single JSON file at `$HOME/.tutorial_todo.json`:

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

**Schema invariants (pinned from open questions in pseudocode):**

- `version` is always `1`. If a future code version reads `version:
  2` and can't parse it, exit 3 with a clear stderr message ("store
  format v2 not supported; please upgrade tutorial").
- `todos` is always a list. Empty list is valid (first-run state).
- Per-todo required fields: `id` (int ≥ 1), `text` (non-empty
  string), `done` (bool), `created_at` (ISO-8601 string).
- `completed_at` is `null` while `done: false`; set to ISO-8601
  string on the transition to `done: true`. Subsequent `done`
  calls do NOT update `completed_at` (idempotency).
- **Forward compat:** any unknown top-level keys are preserved on
  round-trip. Per-todo unknown keys are preserved on that todo.
  The contract is: read the dict, mutate in place, write the
  same dict back. We never re-project.
- ID allocation: `make_id(todos) = (max existing id, or 0) + 1`.
  Ids are monotonic, stable across deletes (deleting id=5 leaves
  id=6 untouched), and start at 1. id=0 is rejected as invalid.

## 3. Data Flow (per user story)

### US-1: add

```
argparse.parse(["add", "buy milk"])
  → cmd_add(args)
    → text = args.text.strip()
    → if not text: err("text required", 2)
    → todos = load_store(path)
    → new_todo = {id: make_id(todos), text, done: false,
                  created_at: now_iso(), completed_at: null}
    → todos.append(new_todo)
    → save_store(path, todos)
    → print(f"added todo {new_todo['id']}: {text}")
    → exit 0
```

### US-2: list

```
argparse.parse(["list"]) or (["list", "--done"]) or (["list", "--open"])
  → cmd_list(args)
    → todos = load_store(path)
    → if args.done: todos = [t for t in todos if t["done"]]
    → elif args.open: todos = [t for t in todos if not t["done"]]
    → if not todos: print("(no todos)"); exit 0
    → for t in sorted(todos, key=lambda t: t["id"]):
        print(f"[{t['id']}] [{'✓' if t['done'] else ' '}] {t['text']}")
    → exit 0
```

### US-3: done

```
argparse.parse(["done", "3"])
  → cmd_done(args)
    → todos = load_store(path)
    → try: t = find_todo(todos, args.id)
    → except NoSuchId: err(f"no todo with id {args.id}", 2)
    → if t["done"]:
        print(f"todo {args.id} already done")
        exit 0   # idempotent
    → t["done"] = True
    → t["completed_at"] = now_iso()
    → save_store(path, todos)
    → print(f"marked todo {args.id} done")
    → exit 0
```

### US-4: delete

```
argparse.parse(["delete", "3"])
  → cmd_delete(args)
    → todos = load_store(path)
    → try: t = find_todo(todos, args.id)
    → except NoSuchId: err(f"no todo with id {args.id}", 2)
    → todos.remove(t)   # by object identity, not by index
    → save_store(path, todos)
    → print(f"deleted todo {args.id}")
    → exit 0
```

### US-5: help

```
argparse --help (or `help` subcommand)
  → argparse auto-generates usage block to stdout
  → exit 0
```

## 4. Failure Modes

| Mode | Detection | Response |
|---|---|---|
| Malformed JSON in store | `json.JSONDecodeError` in `load_store` | Print `store at <path> is malformed: <error>` to stderr, exit 3. **Do not overwrite.** |
| Missing parent dir on write | `OSError` in `save_store` | Print clear stderr message, exit 3. |
| Permission denied on read | `PermissionError` in `load_store` | Print clear stderr, exit 3. |
| Permission denied on write | `PermissionError` in `save_store` | Print clear stderr, exit 3. |
| No such todo id (done/delete) | `find_todo` raises `NoSuchId` | Print `no todo with id <id>` to stderr, exit 2. |
| Invalid id 0 or negative | argparse type-coerces; or our check | Print `no todo with id <id>` to stderr, exit 2. |
| Mid-write crash (process killed) | None — protected by atomic write | Atomic rename guarantees: either the old file or the new file exists, never a half-written one. |
| Concurrent invocations | Not protected | Last-writer-wins. The README warns users not to run two invocations against the same store. (Spec's open question resolved: no locking in v0.4.0.) |
| Unknown subcommand | argparse | Print `unknown command: <name>` to stderr, print usage to stdout, exit 2. |
| `--done` and `--open` both passed | argparse mutually exclusive group | argparse error → exit 2. |
| `$HOME` unset | `KeyError` in path resolution | Print clear stderr, exit 3, before any I/O. |

## 5. Atomic Write Pattern (pinned from pseudocode open question)

```python
import os
import tempfile

def save_store(path, todos):
    dirpath = os.path.dirname(path) or "."
    fd, tmp = tempfile.mkstemp(prefix=".tutorial_todo.", dir=dirpath)
    try:
        os.chmod(tmp, 0o600)  # set restrictive mode atomically at create
        with os.fdopen(fd, "w") as f:
            json.dump({"version": 1, "todos": todos}, f, indent=2)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)  # atomic on POSIX
    except Exception:
        try: os.unlink(tmp)
        except OSError: pass
        raise
```

`os.replace()` is atomic on APFS (macOS) and ext4 (Linux) per the
POSIX rename guarantee. A reader either sees the old file or the
new file, never a partial write.

## 6. Open Questions Resolved

| Open question (from pseudocode) | Resolution |
|---|---|
| argparse `--done/--open` mutual exclusion | Use `argparse.add_mutually_exclusive_group()`; argparse handles the error. |
| Temp file naming + cross-platform mode 0600 | `tempfile.mkstemp` + `os.chmod(fd, 0o600)` immediately after open. |
| Stderr/stdout split ordering | User errors (exit 2): stderr first, usage to stdout. I/O errors (exit 3): stderr only. Success (exit 0): stdout only. |
| Empty list exact string | `(no todos)` on stdout, exit 0. (Pinned in design stage 2.) |
| Forward-compat round-trip | Read dict, mutate in place, write same dict back. Never re-project. |

## 7. Test Strategy

The package doesn't ship tests for `tutorial.py` itself (it's an
example, not production code), but the design supports three test
levels:

1. **Unit tests** of pure functions: `make_id`, `find_todo`,
   `now_iso` (with frozen time).
2. **Storage tests** with a tempdir: write a known dict, load it,
   verify. Write with a corrupted file, verify error.
3. **CLI integration tests** using `subprocess.run` against the
   compiled script. The tempdir is set via `--store /tmp/foo.json`.
   Existing tests in `tests/test_e2e.sh` exercise this pattern.

Manual smoke test (the sparc.config.yaml's `gates.spec` is set to
`approval`, so the tutorial pipeline itself drives the test):
```bash
./tutorial.py add "buy milk"     # expect: added todo 1: buy milk
./tutorial.py list               # expect: [1] [ ] buy milk
./tutorial.py done 1             # expect: marked todo 1 done
./tutorial.py list --done        # expect: [1] [✓] buy milk
./tutorial.py delete 1           # expect: deleted todo 1
./tutorial.py list               # expect: (no todos)
```

## 8. Out of Scope (v0.4.0)

- Tags / labels
- Edit (in-place text modification; delete + re-add for now)
- Sync (cloud, multi-device)
- Config file (no `--config` flag; use the default `~/.tutorial_todo.json`)
- Bash variant (Python only; ~150 lines is small enough)
- Locking (concurrent invocations are last-writer-wins)
- Tests for tutorial.py itself (lives in `examples/`, not `tests/`)
