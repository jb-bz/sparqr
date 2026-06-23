# Pseudocode: tutorial-cli-todo

> Stage 3 of SPARC+Design. High-level logic without implementation details. The Architecture stage will turn this into a system design; the Refinement stage will turn that into code.

## Algorithm Overview

The CLI is a stateless one-shot reader-modifier-writer of a single JSON file. Each invocation loads the full todo list into memory, applies exactly one mutation (add, mark-done, or delete) or no mutation (list, help), then either writes the new list back atomically (write-temp + `os.replace`) or just reads. There is no daemon, no lock, no background process — the design stage has already accepted last-writer-wins for concurrent invocations. Complexity is O(n) per command over the todo list, where n is bounded by a single user's todo volume (tens to low hundreds, not thousands). The interesting design pressure is correctness of the I/O envelope: never leave a half-written file, never overwrite a malformed file, never silently drop a user's data. Every read and write is wrapped in a small set of error envelopes (malformed JSON, missing todo id, unreadable file, unwritable path) that map cleanly to exit codes 2 (user error) and 3 (I/O / corruption).

## Numbered Steps

1. Resolve `--store PATH` if given, otherwise default to `$HOME/.tutorial_todo.json`. Fail early with a clear stderr message and exit 3 if `$HOME` is unset or the resolved path's parent directory is not writable on a write command.
2. Parse argv with `argparse` and dispatch on the subcommand (`add` | `list` | `done` | `delete` | `help`). Unknown subcommand and `help`/`--help` are handled before touching the store.
3. For every subcommand except `help` and unknown-command errors: call `load_store(path)` — read the JSON file, parse it, and return the `todos` list. Missing file is treated as an empty list, not an error. Malformed JSON is a hard error (exit 3) that does NOT overwrite the file. An existing file that is unreadable for permissions is a hard error (exit 3) — refuse to start.
4. **`add <text>`**: validate the text is non-empty after stripping; reject empty text with usage error (exit 2). Generate the next id with `make_id(todos) = (max existing id, or 0) + 1` so ids start at 1 and are monotonic. Build the new todo dict `{id, text, done:false, created_at, completed_at:null}` using the current UTC timestamp in ISO-8601 with seconds precision. Append to the in-memory list, call `save_store`, then print `added todo <id>: <text>` to stdout.
5. **`list [--done | --open]`**: load the store, then filter the list based on the mutually-exclusive flag (default: no filter, show all). If the filtered list is empty, print `(no todos)` on stdout (or stay silent — design decision already pinned in stage 2: print the line). Otherwise print one line per todo in ascending id order in the format `[<id>] [<status>] <text>`, where `<status>` is `✓` for done and a single space for open. No write to the store.
6. **`done <id>`**: load the store, find the todo by id. If not found, print `no todo with id <id>` to stderr and exit 2. If found and already `done: true`, print `todo <id> already done` to stdout and exit 0 (idempotent; do NOT update `completed_at`). If found and open, set `done: true` and set `completed_at` to the current UTC timestamp (only on this transition), call `save_store`, and print `marked todo <id> done` to stdout.
7. **`delete <id>`**: load the store, find the todo by id. If not found, print `no todo with id <id>` to stderr, exit 2, and do not write. If found, remove the todo from the in-memory list (deletion is by id, not index — other ids stay stable), call `save_store`, and print `deleted todo <id>` to stdout.
8. **`help` / `--help` / `-h`**: print a usage block to stdout listing every subcommand with a one-line description, then exit 0. Do not touch the store.
9. **Unknown subcommand**: print `unknown command: <name>` to stderr, print the usage block to stdout, then exit 2. Do not touch the store.
10. **`save_store(path, todos)`**: serialize the full document `{version: 1, todos}` to a temp file in the same directory as the target path, with mode `0600` set atomically at create-time. Flush and `fsync` the temp file. Then `os.replace(temp, path)` — atomic on APFS and ext4 per the POSIX rename guarantee. On any I/O failure, remove the temp file and exit 3 with a stderr message; never leave a half-written store on disk.
11. **`load_store(path)`**: open the file read-only. If it does not exist, return an empty list. Parse with `json.load`. On `JSONDecodeError`, print `store at <path> is malformed: <error>` to stderr and exit 3 — do not write back. On `PermissionError` or `OSError`, print a clear stderr message and exit 3. The top-level dict shape is validated: must have a `todos` key whose value is a list. Extra top-level keys are preserved (forward compat); per-todo extra keys are preserved on each todo dict.
12. **Timestamp helper**: every timestamp is `datetime.now(timezone.utc).isoformat(timespec="seconds")`, producing a string like `2026-06-21T14:32:00+00:00`. There is one helper, `now_iso()`, so all timestamps are formatted identically.
13. **Error helper**: `err(msg, code)` prints to stderr (no decoration, no traceback) and calls `sys.exit(code)`. User errors use code 2; I/O / corruption errors use code 3. Success is code 0.

## Decision Points

### Decision 1: How to dispatch on subcommand
- **Condition**: `argv[1]` after argparse is one of `add` | `list` | `done` | `delete` | `help`
- **Then**: invoke the corresponding `cmd_*` handler with parsed args
- **Else**: fall through to unknown-command handling (step 9) — print to stderr, print usage to stdout, exit 2

### Decision 2: `list` filter
- **Condition**: `--done` flag is set
- **Then**: filter to todos with `done == true`
- **Else if** `--open` flag is set: filter to todos with `done == false`
- **Else** (no flag): show all todos, no filter
- **`--done` and `--open` both set**: argparse enforces mutual exclusion; the second one to be parsed wins (or argparse errors — to be pinned in architecture). Default in argparse is to error on conflicting flags.

### Decision 3: `done` idempotency
- **Condition**: target todo is found and already `done == true`
- **Then**: print `todo <id> already done`, do not write, exit 0
- **Else** (target found and `done == false`): set `done = true`, set `completed_at` to `now_iso()`, write store, print `marked todo <id> done`, exit 0

### Decision 4: id assignment
- **Condition**: existing todo list is non-empty
- **Then**: `new_id = max(existing ids) + 1`
- **Else**: `new_id = 1`
- **Rejected**: id 0 is never assigned; `tutorial done 0` and `tutorial delete 0` are treated as "no such id" (per design stage pin)

### Decision 5: atomic write strategy
- **Condition**: a write command (`add` | `done` | `delete`) is committing a new list
- **Then**: serialize to a temp file in the same directory, set mode `0600`, flush, `os.replace(temp, target)` — atomic on APFS and ext4
- **Else** (read-only commands: `list`, `help`, unknown): no write happens
- **On any I/O error during write**: remove the temp file, print stderr message, exit 3; never overwrite a target that cannot be read back

## Data Structures

### Structure 1: Todo (in-memory dict)
- **Fields**:
  - `id`: int — monotonic, unique, assigned at insert time, starts at 1, stable across deletes
  - `text`: str — non-empty after strip; the user's todo description
  - `done`: bool — `false` at creation, `true` after first successful `done`
  - `created_at`: str — ISO-8601 UTC timestamp with seconds precision, set once at insert
  - `completed_at`: str | null — `null` until first `done`, then ISO-8601 UTC timestamp; never updated after that (idempotency)
- **Lifetime**: created in `cmd_add`, mutated in `cmd_done`, removed in `cmd_delete`; otherwise read-only during a single invocation
- **Owned by**: the in-memory `todos` list for the duration of one CLI invocation; the JSON file across invocations

### Structure 2: Store document (on disk + in memory)
- **Fields**:
  - `version`: int — currently `1`, informational only in v1 (no migration logic yet)
  - `todos`: list of Todo dicts, in ascending id order
- **Lifetime**: persists at `~/.tutorial_todo.json` (or `--store` path) across invocations; loaded into memory at the start of every non-help command
- **Owned by**: the file system; the CLI does not retain state between invocations
- **Forward compatibility**: unknown top-level keys and unknown per-todo keys are preserved on round-trip (read-modify-write the parsed dict, not a re-projection), so a v1.0 reader can load a v1.1 file with a `tags` field without losing it

### Structure 3: argparse Namespace
- **Fields**:
  - `store`: str | None — override path for the JSON store
  - `command`: str — the subcommand name (`add` | `list` | `done` | `delete` | `help`)
  - `text`: str — for `add`
  - `id`: int — for `done` and `delete`
  - `done_flag`: bool — for `list` (the `--done` flag)
  - `open_flag`: bool — for `list` (the `--open` flag)
- **Lifetime**: created by argparse at the start of the invocation, consumed by the `cmd_*` handler, discarded
- **Owned by**: the dispatch layer (step 2); handlers receive it as their only argument

## Edge Cases

| Case | Expected behavior | Notes |
|---|---|---|
| Empty input (`tutorial add ""` or whitespace-only) | exit 2, usage error on stderr | Trim then check non-empty |
| Store does not exist on first `add` | Create the file with this single todo inside, mode `0600` | `load_store` returns `[]` for missing file |
| Store does not exist on `list` | Print `(no todos)`, exit 0; do not create the file as a side effect | Design choice — `list` is read-only |
| Store exists but is malformed JSON | exit 3, stderr message identifying the file and error, do not overwrite | The user's data must not be destroyed |
| Store exists but is not readable (permissions) | exit 3, clear stderr message | Refuse to start; do not silently create a new store |
| `tutorial done 99` with no such id | exit 2, stderr: `no todo with id 99` | Same for `delete 99` |
| `tutorial done 3` on an already-done todo | exit 0, stdout: `todo 3 already done`, do NOT update `completed_at` | Idempotent (US-3) |
| `tutorial done 0` | exit 2, stderr: `no todo with id 0` | id 0 is invalid by convention |
| `tutorial delete 2` on a valid id | Remove the dict; other ids are stable across the delete | Deletion is by id, not index (US-4) |
| Concurrent invocations against the same store | Last-writer-wins; the spec accepts this | No locking in v1; warn in docs |
| Crash mid-write (process killed, power loss) | Store is either the old version or the new version, never a half-written one | `os.replace` is atomic; the temp file is in the same dir and gets cleaned up on next run if the rename never happened |
| `--store` points to a path whose parent does not exist | exit 3 on first write, stderr: parent directory does not exist | Do not `mkdir -p` silently — user must opt in |
| Unknown subcommand `tutorial frobnicate` | stderr: `unknown command: frobnicate`, stdout: usage block, exit 2 | US-5 |
| `tutorial` with no args | stdout: usage block, exit 0 | Treat bare invocation as help |
| `$HOME` unset | exit 3 on any command that needs the default store path, stderr: `$HOME is not set` | Only when `--store` is not given |
| Future version of the file with extra keys (e.g. `tags` on a todo) | Load and re-save preserving those keys | Forward compat: pass-through, not re-projection |
| `--done` and `--open` both set | argparse errors out before the handler runs | Mutual exclusion enforced at parse time |

## Complexity

- **Time**:
  - `load_store`: O(file size) for the JSON parse, O(n) for shape validation
  - `make_id`: O(n) over existing todos (single `max` pass)
  - `cmd_add`: O(n) to compute new id + O(1) append + O(n) write
  - `cmd_list`: O(n) to filter + O(n) to format and print
  - `cmd_done`: O(n) to find by id + O(n) to write
  - `cmd_delete`: O(n) to find by id + O(n) to write
  - `save_store`: O(n) for JSON serialize, O(1) for the atomic rename
  - Overall: O(n) per command, where n is the number of todos — well within budget for a personal todo list (expected n < 1000)
- **Space**:
  - One full copy of the todo list in memory per invocation: O(n)
  - One temp file in the same directory as the store, of the same size: O(n) on disk for the duration of the rename (typically milliseconds)
  - argparse Namespace: O(1)

## Dependencies on Other Components

- **Calls into**:
  - Python 3.8+ stdlib only: `argparse`, `json`, `os`, `os.path`, `sys`, `pathlib`, `datetime` (`datetime.now`, `timezone`), `tempfile`, `stat`
  - The local filesystem (POSIX rename semantics for atomicity)
  - The `HOME` environment variable (only when `--store` is not given)
- **Called by**:
  - The user, directly from a shell, as `tutorial <subcommand> ...` or `python3 tutorial.py <subcommand> ...`
  - The test harness (a `unittest` or `pytest` suite), typically by invoking the script as a subprocess with a temp `--store` path
- **Shared state with**:
  - The JSON store file at `~/.tutorial_todo.json` (or `--store` path) — the only shared state. Concurrent invocations against the same path are explicitly out of scope (last-writer-wins is accepted). The atomic write envelope is the only thing standing between a clean read and a corrupted store.

## Open Pseudocode Questions

- The `argparse` mutual-exclusion behavior for `--done` and `--open` (both set) — the pseudocode assumes argparse errors, but the exact error message and whether `--help` still fires should be pinned in the Architecture stage so the test suite can assert on it.
- The temp-file naming convention (e.g. `.<original>.tmp` vs `tempfile.NamedTemporaryFile`) — `NamedTemporaryFile` is safer (uniquely named, auto-cleaned on close) but creates the file with default mode `0600` only on Linux. The architecture stage should pin the exact `os.open` + `os.chmod` + `os.write` pattern that guarantees mode `0600` on both macOS and Linux.
- The exact stderr/stdout split for unknown commands — pseudocode says "stderr message + stdout usage block + exit 2", matching US-5, but the test harness will need a single canonical line ordering to assert on. Pin in architecture.
- Whether `tutorial list` should print `(no todos)` on stdout or stay silent when the store is empty — design stage pinned this as "print the line", but the test assertion will need a single literal string. Pin in architecture (current pin: `(no todos)`).
- Forward-compat round-trip: pseudocode assumes "preserve unknown keys", but the implementation will need a clear contract about which dict is written back (the parsed top-level dict, with only `todos` being the source of truth). Architecture should pin whether the implementation re-serializes the entire parsed dict or constructs a fresh `{version, todos}` object on each save — these are behaviorally different if a third party adds a top-level `metadata` field.
