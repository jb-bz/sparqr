# Specification: tutorial-cli-todo

> Stage 1 of SPARC+Design. The artifact downstream stages build on. Get this right; the rest follows.

## Goal

`tutorial-cli-todo` is a minimal, single-binary command-line todo list that lives entirely on the user's machine. It exists so a learner working through the SPARC+Design methodology has a small but realistic artifact to drive the pipeline — small enough to spec in one sitting, but rich enough to exercise every stage (CLI parsing, file I/O, JSON schema, error paths, cross-platform behavior). The target user is a developer who wants to track a handful of tasks without spinning up a web app, a database, or a TUI framework. Success looks like: a user types `tutorial add "buy milk"`, comes back the next day, types `tutorial list`, sees their todos still there, marks one done, and deletes another — and it just works on macOS and Linux without installing anything beyond Python 3 (already present on both).

## User Stories

### US-1: Add a todo

As a developer, I want to add a todo from the command line with a short text description, so that I can capture a task in under two seconds without leaving the terminal.

**Acceptance Criteria:**
- Given the JSON store exists and is valid, When I run `tutorial add "buy milk"`, Then a new todo with the given text is appended, gets a unique numeric id, has `done: false`, has the current ISO-8601 timestamp in `created_at`, and the response prints the new id and text on stdout.
- Given the JSON store does not exist, When I run `tutorial add "buy milk"`, Then the store is created at `~/.tutorial_todo.json` with this single todo inside.
- Given the JSON store exists but is malformed (invalid JSON), When I run `tutorial add "buy milk"`, Then the command exits non-zero with a clear error message on stderr, and the existing file is NOT overwritten.
- Given I run `tutorial add` with no argument, When the command runs, Then it exits non-zero with a usage error on stderr and prints the usage line on stdout.

### US-2: List todos

As a developer, I want to list all my todos (open and done), so that I can review what I have committed to at a glance.

**Acceptance Criteria:**
- Given there are open and done todos in the store, When I run `tutorial list`, Then every todo is printed one per line in the format `[<id>] [<status>] <text>` where `<status>` is `✓` for done and ` ` (space) for open, ordered by ascending id.
- Given the store does not exist, When I run `tutorial list`, Then it prints an empty list (no error, exit 0) and creates an empty store file as a side-effect.
- Given there are zero todos, When I run `tutorial list`, Then the command exits 0 and prints nothing on stdout (or a single "(no todos)" line — pick one and document it).
- Given I run `tutorial list --done`, When the command runs, Then only completed todos are shown.
- Given I run `tutorial list --open`, When the command runs, Then only todos with `done: false` are shown.

### US-3: Mark a todo as done

As a developer, I want to mark a todo as done by its id, so that I can track progress without deleting the record.

**Acceptance Criteria:**
- Given a todo with id 3 exists and is open, When I run `tutorial done 3`, Then the todo's `done` field is set to `true`, a `completed_at` field is set to the current ISO-8601 timestamp, the command exits 0, and stdout prints a confirmation including the id.
- Given a todo with id 3 is already done, When I run `tutorial done 3`, Then the command is idempotent: it exits 0, prints an "already done" message, and does NOT update `completed_at`.
- Given no todo with id 99 exists, When I run `tutorial done 99`, Then the command exits non-zero and prints "no todo with id 99" on stderr.
- Given I run `tutorial done` with no id, When the command runs, Then it exits non-zero with a usage error.

### US-4: Delete a todo

As a developer, I want to delete a todo by its id, so that I can remove tasks I no longer care about.

**Acceptance Criteria:**
- Given a todo with id 2 exists, When I run `tutorial delete 2`, Then that todo is removed from the store, the command exits 0, and stdout prints a confirmation including the deleted id.
- Given no todo with id 99 exists, When I run `tutorial delete 99`, Then the command exits non-zero with "no todo with id 99" on stderr and the store is unchanged.
- Given I run `tutorial delete` with no id, When the command runs, Then it exits non-zero with a usage error.
- Given a todo is deleted, When I subsequently run `tutorial list`, Then no other todo's id changes (deletion is by id, not by index — ids are stable across deletions).

### US-5: See usage

As a developer, I want to see usage information, so that I can discover available subcommands without reading the source.

**Acceptance Criteria:**
- Given any invocation, When I run `tutorial` or `tutorial help` or `tutorial --help` or `tutorial -h`, Then stdout prints a usage block listing all subcommands with a one-line description of each, and the command exits 0.
- Given an unknown subcommand, When I run `tutorial frobnicate`, Then stderr prints "unknown command: frobnicate" and stdout prints the usage block, and the command exits non-zero.

## Success Metrics

- **Install time**: zero steps beyond copying one file to somewhere on `PATH` (or invoking the script directly). Measured as: `time tutorial --help` returns in < 50ms cold start on a MacBook Air M1.
- **Dependency count**: 0 third-party packages. Only Python 3.8+ stdlib (or bash + `jq` + `date`, for the alternative implementation).
- **Cross-platform coverage**: `tutorial list` returns identical output on macOS 15+ and Ubuntu 22.04+ when pointed at the same JSON file. Verified by smoke test on both.
- **Crash-free runs**: 100% of the acceptance-criteria invocations above exit 0 on success paths and non-zero with a stderr message on every documented failure path. Zero uncaught exceptions during the tutorial walkthrough.
- **Persistence durability**: a todo added on day N is still present and loadable on day N+30, even after the host reboots, on a read-only file system reinstall, etc. Verified by manually re-opening the store after a forced reboot.
- **Time-to-first-todo**: a brand-new learner can go from `git clone` to first successful `tutorial add "..."` in under 5 minutes (reading the spec + running the one install command).

## Constraints

- **Language / framework**: Python 3.8+ stdlib only (preferred implementation). A Bash + `jq` implementation is acceptable as an alternative if it lands smaller, but it is not required for the tutorial to ship.
- **Deployment**: Single file, runnable directly (`python3 tutorial.py add "..."`) and ideally also symlink-able to a `PATH` location. No `pip install`, no virtualenv, no Docker.
- **Data privacy**: All data lives on the user's machine at `~/.tutorial_todo.json`. No network calls. No telemetry. No environment variables read except `HOME` (to find the store).
- **File-system permissions**: The tool must create the JSON store with mode `0600` (user read/write only) on first creation, and must preserve permissions on subsequent writes.
- **Concurrency**: Single-user, single-process. No locking. The tutorial docs must warn the user not to run two `tutorial` invocations concurrently against the same store. No locking means we lose the last-writer-wins race — that's accepted for v1.
- **Concurrent atomicity**: Every write to the JSON store must be atomic on the local filesystem (write-temp + `os.replace`) so a crash mid-write never leaves a half-written store.
- **Rate limits**: N/A — no external services.
- **Browser support**: N/A — CLI only.
- **Dependencies**: No new third-party dependencies. If the Bash variant ships, `jq` is the only external dep, and the installer must detect absence and instruct the user.

## Spike Tasks (unknowns to research first)

- [ ] Confirm `os.replace()` is atomic on both APFS (macOS) and ext4 (Linux) for the tutorial VM. If not, fall back to write-then-rename via a sibling temp file.
- [ ] Decide whether the tutorial ships both the Python and the Bash variant, or only one. Criterion: the smallest artifact that still demonstrates cross-platform behavior.
- [ ] Verify `~/.tutorial_todo.json` doesn't collide with any well-known dotfile on the typical dev's machine. If a collision is possible, rename to `~/.tutorial_todo_store.json`.
- [ ] Confirm the JSON schema is forward-compatible: if v1.1 adds a `tags` field, can v1.0 still load a v1.1 file without crashing? (Answer should be "yes" because we ignore unknown keys — make that explicit in the design stage.)
- [ ] Decide on id generation: monotonic integer assigned at insert time, or UUID? Criterion: human-typability from the command line favors small integers. Confirm this is the right call.

## Out of Scope

- **Tags, projects, due dates, priorities** — explicit v2 candidates. Not in this spec.
- **Multiple lists / workspaces** — single flat list only in v1.
- **Sync across machines / cloud backup** — explicitly out. The file is local, full stop.
- **Interactive REPL / TUI mode** — explicit v2 candidate. v1 is subcommand-only, one invocation per action.
- **Edit-in-place of a todo's text** — explicit v2. v1 workflow is delete + re-add.
- **Migration path for legacy todo formats** (e.g. from TaskPaper, todo.txt) — not in this spec.
- **Shell completion files** (bash/zsh/fish) — nice-to-have but explicitly out of v1 to keep the artifact small.
- **Internationalization of messages** — English-only error and status strings in v1.

## Open Questions

- Should `tutorial list` show a single `(no todos)` line when the store is empty, or be silent? This is a UX call that should be resolved during the design stage by reading one tutorial walkthrough aloud.
- Should `tutorial done 0` (id zero) be rejected as "no such id", or treated as valid? Convention is to start ids at 1, but the spec doesn't pin that — the design stage should pin it.
- For the Python implementation, do we use `argparse` (stdlib, verbose) or hand-roll the parser (smaller, fewer features)? Default to `argparse` for clarity; revisit if the script grows past ~150 lines.
- Should the tool refuse to start if `~/.tutorial_todo.json` exists but is not readable by the current user? (Almost certainly yes, but pin it.)
