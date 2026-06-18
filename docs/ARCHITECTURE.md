# Architecture

This document explains how the pieces of the SPARC+Design package fit together. Read this if you want to understand the design or contribute changes.

## The 30,000-foot view

```
                 ┌─────────────────────────────────────┐
                 │           YOU (the human)           │
                 └────────────┬───────────────┬────────┘
                              │               │
                  reviews via │               │ monitors via
                              ▼               ▼
       ┌────────────────────────────────────────────────────┐
       │      HITL ADAPTER (terminal / tui / webui /        │
       │      workspace / official-dashboard)               │
       └─────────────────────┬──────────────────────────────┘
                             │ notify / await_reply
                             ▼
       ┌────────────────────────────────────────────────────┐
       │   SPARC-PIPELINE ORCHESTRATOR DAEMON               │
       │   (bin/sparc-pipeline, polls every 3s)             │
       │                                                    │
       │   • Watches Hermes Kanban for `ready` tasks        │
       │   • Spawns the right profile for each task         │
       │   • Watches Hermes Kanban for `blocked` tasks      │
       │   • Surfaces HITL review requests                  │
       │   • Applies APPROVE/REDIRECT/REJECT decisions     │
       └─────────────────────┬──────────────────────────────┘
                             │ spawns
                             ▼
       ┌────────────────────────────────────────────────────┐
       │   STAGE AGENTS (sparc-spec, sparc-design, etc.)    │
       │   Each is a Hermes session in a per-stage profile. │
       │                                                    │
       │   Reads parent context from kanban comment thread. │
       │   Writes artifact to disk + mirrors to kanban.     │
       │   Calls kanban_complete or kanban_block.           │
       └─────────────────────┬──────────────────────────────┘
                             │ reads/writes
                             ▼
       ┌────────────────────────────────────────────────────┐
       │   HERMES KANBAN  (durable SQLite per board)        │
       │   Parent→child DAG via task_links.                 │
       │   This is the single source of truth for state.    │
       └────────────────────────────────────────────────────┘
```

## The data flow for a single stage transition

1. **Stage N agent finishes.** It writes `docs/sparc/<board>/<stage>/<task-id>.md` to disk, mirrors the artifact to the kanban comment thread, and calls either `sparc_kanban_complete` (no review) or `sparc_kanban_block` (review needed).
2. **Dispatcher sees the new state** (3s polling). The `task_links` parent→child DAG means stage N+1's task is now eligible to move from `todo` → `ready`. (Hermes Kanban's dispatcher does this automatically.)
3. **Orchestrator picks up the ready task.** Sees the `task_id` and the stage (from the title prefix `[STAGE]`). Looks up the profile and skill for that stage in `lib/stages.sh`. Spawns `hermes -p <profile> chat -q "..."` in the background.
4. **Stage N+1 agent runs.** Reads parent's comment thread, reads parent's artifact, does the work, publishes its own artifact, advances state.
5. **If the stage is a HITL gate, the orchestrator interrupts the loop.** When it sees a `blocked` task, it calls `hitl_notify` on the configured adapter. The adapter surfaces the review (in whatever UI the user chose). The orchestrator blocks on `hitl_await_reply` until the human responds.
6. **On APPROVE**: orchestrator calls `sparc_kanban_unblock` → task goes to `done` → next stage auto-promotes to `ready` → loop continues.
7. **On REDIRECT**: orchestrator adds the human's note as a comment, sets status back to `ready`, and the loop re-spawns the same stage agent with the new guidance as context.
8. **On REJECT**: orchestrator archives the task. The pipeline halts at this stage. The user can `sparc pipeline stop` and start over, or `sparc hitl redirect <task> "continue with..."` to resume.

## The 6 stages

| # | Stage | Profile | Skill | Template | Default HITL? |
|---|---|---|---|---|---|
| 1 | Specification  | `sparc-spec`         | `sparc-stage-spec`     | `templates/specification.md` | yes |
| 2 | Design         | `sparc-design`       | `sparc-stage-design`   | `templates/design.md`        | no  |
| 3 | Pseudocode     | `sparc-pseudocode`   | `sparc-stage-helpers`  | `templates/pseudocode.md`    | no  |
|4  | Architecture   | `sparc-architecture` | `sparc-stage-helpers`  | `templates/architecture.md`  | yes |
| 5 | Refinement     | `sparc-refinement`   | `sparc-stage-helpers` + TDD | `templates/refinement.md` | no  |
| 6 | Completion     | `sparc-completion`   | `sparc-stage-helpers`  | `templates/completion.md`    | yes |

HITL gate placement is configurable per-project in `sparc.config.yaml` under `hitl_gates`. The defaults match the `agentpatterns.ai` reversibility-aware gating heuristic: gate what you can't easily redo (spec, arch, completion) and skip what you can (design, pseudo, refinement — they can be re-done without consequence).

## The 7 profiles

```
sparc-spec          (stage 1,  generic)
sparc-design        (stage 2,  community extension)
sparc-pseudocode    (stage 3,  generic)
sparc-architecture  (stage 4,  generic)
sparc-refinement    (stage 5,  loads TDD + systematic-debugging companion skills)
sparc-completion    (stage 6,  generic)
sparc-reviewer      (HITL gate, NOT a stage — handles human review)
```

Profiles are pure configuration — they set the per-stage circuit breakers (`max_turns`, `terminal.timeout`, `delegation.max_iterations`) and preload the right skill. See `profiles/*.yaml` for the full config of each.

## The durable state

Three things are durable across the pipeline's lifetime:

1. **Hermes Kanban** (`~/.hermes/kanban/boards/<slug>/kanban.db`) — the single source of truth for state. Task status, comments, links, all survive restarts and context compression.
2. **Disk artifacts** (`./docs/sparc/<board>/<stage>/<task-id>.md` by default) — the human-readable record of what each stage produced. The "belt" of "belt and suspenders."
3. **Kanban comment thread** (same DB, separate rows) — the same artifact, mirrored. The "suspenders." This is what the next stage's agent reads as context.

If you ever lose one, the other has the same data. This is by design — Hermes auto-compaction has been known to lose critical artifacts; the dual-store pattern prevents that.

## The HITL adapter contract

The orchestrator never calls a HITL surface directly. It calls `hitl_notify` and `hitl_await_reply` from `lib/adapters/hitl/_registry.sh`. The registry dispatches to the configured adapter by name. The adapter has full responsibility for the surface-specific API and reply-collection mechanism.

To add a new adapter, see [HITL.md § Authoring a HITL adapter](HITL.md#authoring-a-hitl-adapter).

## The orchestrator's loop, in detail

The orchestrator (`bin/sparc-pipeline`) runs a single infinite loop:

```bash
while true; do
  once_tick
  sleep 3
done
```

`once_tick` is two passes:

**Pass 1 — process blocked tasks (HITL).** For each task with status `blocked`:
1. Get the stage from the title prefix (`[STAGE]`).
2. Find the artifact on disk.
3. Call `hitl_notify` on the configured primary adapter — pushes a review request to the surface.
4. Call `hitl_await_reply` — blocks until the human responds.
5. Interpret the reply (APPROVE / REDIRECT / REJECT) and call the right kanban verb.

**Pass 2 — process ready tasks (spawn).** For each task with status `ready`:
1. Get the stage from the title prefix.
2. Look up the profile and skill in `lib/stages.sh`.
3. Set status to `running` (so we don't double-spawn).
4. Spawn `hermes -p <profile> chat -q "..."` in the background, redirecting to a per-task log.

That's it. No magic, no framework. A 200-line bash daemon.

## Why bash?

Because the orchestrator's job is *coordination*, and coordination code:
- Should be readable without a language ecosystem
- Should have zero runtime dependencies beyond `bash` and the CLI tools it wraps
- Should be testable with `bash -n` and shell-based unit tests
- Should be replaceable — if you don't like the orchestrator, write your own in Python or Go

The agents themselves are still full Hermes sessions in full Python. The bash daemon is just the glue.

## What this design optimizes for

- **Reliability over cleverness.** Polling, not subscriptions. Idempotent verbs. No state machine more complex than `triage | todo | ready | running | blocked | done | archived`.
- **Composability.** You can replace any one layer (orchestrator, adapter, agent) without rewriting the others.
- **Auditability.** Every transition is a row in the kanban DB. Every artifact is on disk. Every review is a comment. The whole pipeline is replayable from the DB.
- **Recoverability.** Restart the daemon, the pipeline resumes. Restart an agent, the comment thread has the context. Restart the user, the doc explains what to do.

## What this design does NOT optimize for

- **Latency.** The 3-second polling interval means worst-case 3s lag between stage completion and next-stage spawn. If you need <1s, write a real event subscription (kanban doesn't expose one yet — see [TROUBLESHOOTING.md § Replacing the poller with events](TROUBLESHOOTING.md)).
- **Throughput.** One task per stage at a time. If you need parallel stages (rare in SPARC, but possible), fork the orchestrator or use a different framework.
- **Cloud-native.** This is a single-machine design. If you want a serverless version, port it; the design supports it (each layer is stateless except for the kanban DB).

## Reference

- `lib/stages.sh` — stage table (data, not code)
- `lib/kanban.sh` — kanban verb wrappers
- `lib/artifacts.sh` — dual-store artifact policy
- `lib/validators.sh` — stage transition validators
- `lib/adapters/hitl/_registry.sh` — adapter dispatch
- `bin/sparc-pipeline` — orchestrator daemon
- `bin/sparc` — CLI entry point
