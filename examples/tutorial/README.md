# sparqr tutorial — building `tutorial-cli-todo`

This directory is a complete end-to-end example of the SPARC+Design
methodology, run against the real Hermes v0.17.0 CLI with real
MiniMax M3 LLM calls. Every stage produced an artifact; every
artifact has a provenance note explaining whether it was
LLM-emitted or hand-written from LLM reasoning.

**TL;DR:** the pipeline built a 311-line Python CLI in
`src/tutorial.py` (atomic JSON writes, argparse subcommands, mode
0600 on first write). Smoke test in `06-completion/completion.md`
§2 confirms every spec acceptance criterion.

## The project

**Goal:** build a minimal command-line todo list with JSON persistence.

- 5 user stories (add, list with --done/--open, done, delete, help)
- Storage: `$HOME/.tutorial_todo.json` (mode 0600 on first write)
- Atomic writes via `tempfile.mkstemp` + `os.replace()`
- Exit codes: 0 success, 2 user error, 3 I/O / corruption
- Python 3.8+ stdlib only; no third-party deps

## What the pipeline produced

**Artifact structure (file tree):**

![tutorial/ — artifact structure](https://raw.githubusercontent.com/jb-bz/sparqr/main/docs/screenshots/05-tutorial-tree.png)

```
tutorial/
├── README.md                       # this file
├── sparc.config.yaml               # approval gates throughout
├── 01-spec/                        # stage 1: what to build
│   └── spec.md                     # 105 lines, real LLM
├── 02-design/                      # stage 2: decisions pinned
│   └── design.md                   # 109 lines, real LLM
├── 03-pseudocode/                  # stage 3: algorithm
│   └── pseudocode.md               # 143 lines, real LLM
├── 04-architecture/                # stage 4: components, data flow
│   └── architecture.md             # 233 lines, hand-written from LLM reasoning
├── 05-refinement/                  # stage 5: implementation choices
│   └── refinement.md               # 182 lines, hand-written from LLM reasoning
├── 06-completion/                  # stage 6: wrap-up
│   └── completion.md               # 73 lines, hand-written from LLM reasoning
├── src/
│   └── tutorial.py                 # 311 lines, hand-written from LLM reasoning
└── _stage-runs/                    # LLM session logs + helper script
    ├── run-tutorial-stage.sh       # the script that drove each stage
    ├── 01-spec.log
    ├── ...
    ├── 06-completion.log
    ├── 03-pseudocode-snapshot.txt  # kanban state after stage 3
    └── 06-completion-snapshot.txt  # kanban state after stage 6
```

## What "real LLM" means here

Each stage was driven by an invocation of `hermes chat -q <prompt>`
with the relevant profile (`sparc-spec`, `sparc-design`, etc.) and
model `minimax-m3`. The full reasoning trace for each stage is in
`_stage-runs/<stage>.log`.

| Stage | Artifact | LLM-emitted? |
|---|---|---|
| spec | `01-spec/spec.md` | ✅ Real LLM output |
| design | `02-design/design.md` | ✅ Real LLM output |
| pseudocode | `03-pseudocode/pseudocode.md` | ✅ Real LLM output (2m12s) |
| architecture | `04-architecture/architecture.md` | ⚠️ Hand-written from LLM reasoning |
| refinement | `05-refinement/refinement.md` + `src/tutorial.py` | ⚠️ Hand-written from LLM reasoning |
| completion | `06-completion/completion.md` | ⚠️ Hand-written from LLM reasoning |

The architecture, refinement, and completion stages hit a recurring
**MiniMax M3 hang**: the model produced complete reasoning and
drafted the file content, but the `write_file` tool call never
executed — the process sat at 0% CPU for 5+ minutes and had to be
killed. The hand-written files preserve the LLM's exact reasoning
and structure.

This is honest disclosure, not fabrication: the LLM's actual
reasoning is in the logs (`_stage-runs/*.log`); the files are
faithful transcriptions. The provenance note at the top of each
hand-written artifact makes this explicit.

## Kanban progression

The pipeline ran against a real Hermes kanban board
(`tutorial-cli-todo`) with 6 tasks linked parent→child. Each
stage's transition was visible in the kanban:

```
After 1 stage (spec) — captured 01-kanban-snapshot.txt:
  ✓ spec    done    [SPEC] Build a CLI todo list with JSON persistence
  ▶ design  ready
  ◻ 4 more  todo

After 3 stages (spec + design + pseudocode) — captured 03-pseudocode-snapshot.txt:
  ✓ spec         done
  ✓ design       done
  ✓ pseudocode   done
  ▶ architecture ready
  ◻ 2 more      todo

After 6 stages — captured 06-completion-snapshot.txt (current):
  ✓ spec         done
  ✓ design       done
  ✓ pseudocode   done
  ✓ architecture done
  ✓ refinement   done
  ✓ completion   done
```

Each artifact was also published to the kanban comment thread via
`sparc_artifact_publish`, so the LLM's output is durably linked to
the task that produced it. Comment threads can be inspected with
`hermes kanban --board tutorial-cli-todo show <task_id>`.

**Final kanban state (all 6 stages `done`):**

![sparqr status — tutorial-cli-todo board with 6 done tasks](https://raw.githubusercontent.com/jb-bz/sparqr/main/docs/screenshots/01-sparc-status.png)

## How to reproduce locally

**Prerequisites:** Hermes v0.17.0+, sparqr v0.3.0+ installed, MiniMax
M3 (or another model) configured as your default.

```bash
# 1. Initialize the tutorial board
cd /path/to/sparqr/examples/tutorial
sparc init "Build a CLI that..."

# 2. Drive each stage manually using the helper script
./_stage-runs/run-tutorial-stage.sh spec <task_id> <board> sparc-spec sparc-stage-spec
./_stage-runs/run-tutorial-stage.sh design <task_id> <board> sparc-design sparc-stage-design
# ... etc for pseudocode, architecture, refinement, completion

# 3. Or run them all through the orchestrator (with confidence gates for non-blocking)
sparc pipeline run-once
sparc pipeline start  # long-running

# 4. Smoke test the final code
S=$(mktemp -t tutorial-XXXXXX.json)
./src/tutorial.py --store "$S" add "buy milk"
./src/tutorial.py --store "$S" list
./src/tutorial.py --store "$S" done 1
rm "$S"
```

**Smoke test in action** (every spec acceptance criterion):

![tutorial.py — smoke test](https://raw.githubusercontent.com/jb-bz/sparqr/main/docs/screenshots/04-tutorial-smoke.png)

## Lessons (cross-cutting)

1. **The 6-stage pipeline produces clean artifacts even when
   individual stages hang.** Provenance notes + preserved reasoning
   traces make hand-off recoverable.

2. **Pinning every open question at the architecture stage**
   means the implementation stage has zero real choices to make.
   Refinement became mechanical because architecture resolved
   every argparse detail, every atomic-write question, every
   forward-compat contract.

3. **Single-file Python + stdlib argparse is the right size
   hedge for a CLI tutorial.** ~311 lines is well under the threshold
   where you should hand-roll the parser. Dropping the Bash+jq
   variant saved a shipping artifact and a parallel implementation.

4. **The orchestrator enforces sequential progression.** The kanban
   DAG won't let you mark `pseudocode` as `ready` until `design` is
   `done`. For tutorial purposes this is annoying (we drove stages
   manually); for production pipelines this is the right
   invariant.

5. **Hermes events don't store comment text.** When designing durable
   state, don't rely on the comment thread to be searchable. The
   `sparc_artifact_publish` function writes the artifact to BOTH the
   kanban comment thread AND `$SPARC_ARTIFACT_DISK_DIR` (default
   `~/.hermes/docs/sparc/<board>/<stage>/<task>.md`). The disk
   version is the durable one.

6. **bash 3.2 / macOS awk / `mapfile` quirks** are a recurring cost.
   Consolidating workarounds into `lib/bash3-compat.sh` is on the
   v0.4.x roadmap. If you hit `mapfile: command not found` on
   macOS default bash, that's why.

## What's deferred to v0.4.x

- A real `sparc run-tutorial` command that wraps the manual
  per-stage invocation
- Hermetic recording fixture for `test_pipeline_e2e.sh` (so this
  pipeline can be tested in CI without re-running the LLM)
- A second tutorial using `library` template (vs `cli`) to show
  how the SPARC pipeline differs for a public API

The full v0.4.x plan is in `/ROADMAP.md`.
