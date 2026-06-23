# Completion: tutorial-cli-todo

> Stage 6 of SPARC+Design. Final wrap-up.

## 1. What was shipped

`tutorial-cli-todo` is a single-file, zero-dependency Python 3.8+ stdlib CLI todo list. One invocation = one atomic read-modify-write of a versioned JSON store at `~/.tutorial_todo.json` (mode `0600`, atomic via `tempfile.mkstemp` + `os.replace`). Five subcommands — `add <text>`, `list [--done|--open]`, `done <id>` (idempotent), `delete <id>`, `help` — satisfy all five user stories (US-1..US-5) in `spec.md`. The implementation is `src/tutorial.py` (311 lines), produced end-to-end by the 6-stage SPARC+Design pipeline (Spec → Design → Pseudocode → Architecture → Refinement → Completion).

## 2. How to verify

Smoke test against a temp store (keeps real `~/.tutorial_todo.json` untouched):

```bash
cd /Users/jolonbankey/Documents/AAA-Agents/hermes/sparc-orchestration-2026-06/package/examples/tutorial
S=$(mktemp -t tutorial-XXXXXX.json)
./src/tutorial.py --store "$S" add "buy milk"     # added todo 1: buy milk
./src/tutorial.py --store "$S" add "walk dog"     # added todo 2: walk dog
./src/tutorial.py --store "$S" list               # both, formatted [id] [ ] text
./src/tutorial.py --store "$S" done 1             # marked todo 1 done
./src/tutorial.py --store "$S" list --done        # only the done todo
./src/tutorial.py --store "$S" list --open        # only the open todo
./src/tutorial.py --store "$S" delete 2           # deleted todo 2
./src/tutorial.py --store "$S" list               # (no todos)
./src/tutorial.py --store "$S" done 1             # todo 1 already done (idempotent)
./src/tutorial.py --store "$S" done 99 2>/dev/null; echo "exit=$?"   # exit=2
./src/tutorial.py --store "$S" add ""  2>/dev/null; echo "exit=$?"   # exit=2
./src/tutorial.py --store "$S" help               # usage block on stdout
./src/tutorial.py --store "$S" frobnicate 2>/dev/null; echo "exit=$?"   # exit=2
rm "$S"
```

Expected: all success paths exit 0; user-error paths exit 2 with a stderr message; no uncaught exceptions; the temp store file is always valid JSON with `{version: 1, todos: [...]}`.

## 3. What was learned

- **Stage hangs are recoverable when provenance is preserved.** Two of the five LLM-driven stages (Architecture, Refinement) hung at file-generation time despite producing complete reasoning traces. Capturing the trace to `_stage-runs/<stage>.log` and noting the hang in the artifact's "Provenance" section let a human re-emit the file from the same reasoning without losing fidelity.
- **Pin every open question at the architecture stage.** Refinement became trivial because Architecture resolved the argparse `--done/--open` mutual-exclusion, the atomic write pattern (`tempfile.mkstemp` + `os.chmod` + `os.replace`), the exact `(no todos)` empty-list string, and the read-modify-write-no-reproject forward-compat contract. Zero real choices were left for Refinement to make.
- **Single-file Python + stdlib argparse was the right size hedge.** Dropping the Bash+jq variant at Design stage saved a shipping artifact and a parallel implementation; ~311 lines is well under the ~150-line trigger for "should we hand-roll the parser instead".

## 4. Caveats

- **Two LLM hangs.** Architecture (target ~150-line output) and Refinement (target ~311-line code) both hung for 5+ minutes with 0% progress after producing complete reasoning. Both files are hand-written from the captured reasoning traces, not LLM-emitted. See `architecture.md` §Provenance and `refinement.md` §Provenance.
- **No tests ship for `tutorial.py`.** The tutorial artifact lives under `examples/`, not `tests/`. The smoke test above is the only verification; the LLM-suggested unit tests for `make_id` / `find_todo` / `now_iso` were not added.
- **Malformed-store recovery not verified end-to-end.** The implementation correctly refuses to overwrite a malformed store (exit 3), but no smoke step exercises it; user must trust the code path or write a test.
- **Concurrent invocations are last-writer-wins.** Spec accepts this for v1; no file locking. README warns the user. Crash mid-write is protected by `os.replace` atomicity on APFS/ext4.
- **Bash variant dropped.** Design stage decided to ship Python only. Spec's alternative-impl clause was satisfied by the simplification.
- **Resolved-open-questions drift between design and refinement.** Architecture pinned `args.open` (no trailing underscore); Refinement §2 flags that the LLM's first draft used `dest="open_"` to dodge a builtin-shadowing worry that turned out to be a non-issue. Final code is correct, but the documented reasoning trail shows the correction.