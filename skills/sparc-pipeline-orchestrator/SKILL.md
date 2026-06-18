---
name: sparc-pipeline-orchestrator
description: Orchestrate the SPARC+Design pipeline by watching the Hermes Kanban board, spawning stage agents, and surfacing HITL reviews to the configured adapter.
version: 0.1.0
author: Hermes SPARC Package
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [sparc, orchestration, kanban, hitl, multi-agent]
    related_skills: [sparc-hitl-watcher, sparc-stage-helpers, kanban]
    category: software-development
---

# SPARC Pipeline Orchestrator

This skill is loaded automatically by Hermes sessions that are spawned by the `sparc pipeline` daemon, and by the `sparc-reviewer` profile. It teaches the agent the SPARC+Design protocol: how to read the parent task's comment thread for context, how to publish artifacts, how to call the right kanban verbs to advance the pipeline, and how to surface HITL reviews.

## When this skill loads

- A `sparc-*` profile is active (set by `setup.sh`)
- The user says "sparc" or "run the sparc pipeline"
- The orchestrator daemon spawns a stage agent via `hermes -p <profile> chat -q "..."`

## The protocol

When you start a session with this skill loaded, follow these steps in order:

### 1. Identify your stage

The orchestrator (or the user) will pass you the stage in your prompt. Possible values: `spec`, `design`, `pseudocode`, `architecture`, `refinement`, `completion`. Do not deviate from the assigned stage.

### 2. Read upstream context

```bash
# List the board (you should already be on the right board per env)
hermes kanban boards list

# Show your specific task
hermes kanban --board "$SPARC_BOARD" show "$TASK_ID"

# The comment thread carries the upstream artifacts. Read it.
hermes kanban --board "$SPARC_BOARD" show "$TASK_ID" --comments
```

### 3. Read the template

```bash
cat ~/.hermes/skills/software-development/sparc-stage-helpers/templates/<stage>.md
```

Wait — the templates live in the package, not in the skill. Use:

```bash
cat $SPARC_PKG_ROOT/templates/<stage>.md
# or, if not set:
cat $(sparc --version >/dev/null 2>&1 && dirname $(which sparc)/..  || echo ~/.local/share/sparc-package)/templates/<stage>.md
```

In practice, the package's templates are at `~/.hermes/sparc-package/templates/<stage>.md` after setup, and `$SPARC_PKG_ROOT` is set by the orchestrator before spawning you.

### 4. Do the work

Use your normal tools + the relevant companion skills:

| Stage | Companion skills (auto-loaded by profile) |
|---|---|
| spec         | (this skill, plus sparc-stage-helpers) |
| design       | sparc-stage-design |
| pseudocode   | sparc-stage-helpers |
| architecture | sparc-stage-helpers |
| refinement   | sparc-stage-helpers + (TDD) + (systematic-debugging) |
| completion   | sparc-stage-helpers |

### 5. Write the artifact to disk

```bash
ARTIFACT_DIR="${SPARC_ARTIFACT_DISK_DIR:-./docs/sparc}/$SPARC_BOARD/$STAGE/$TASK_ID.md"
mkdir -p "$(dirname "$ARTIFACT_DIR")"
```

Write the full artifact (the rendered template, filled in) to this path.

### 6. Publish (disk + kanban)

```bash
source ~/.hermes/sparc-package/lib/artifacts.sh
sparc_artifact_publish "$SPARC_BOARD" "$STAGE" "$TASK_ID" "$(cat $ARTIFACT_DIR)"
```

This writes to disk AND mirrors to the kanban comment thread in one call.

### 7. Advance the pipeline

If your stage does NOT require human review (see `sparc stages` to check), call:

```bash
source ~/.hermes/sparc-package/lib/kanban.sh
sparc_kanban_complete "$SPARC_BOARD" "$TASK_ID"
```

The orchestrator will see the new `done` state, find the next stage's task (which is already in `ready` thanks to the parent→child `task_links` DAG), and spawn its agent.

If your stage DOES require human review, call:

```bash
sparc_kanban_block "$SPARC_BOARD" "$TASK_ID" "<one-line summary of what to review>"
```

Then EXIT. Do not wait for the human. The orchestrator's HITL watcher (running in parallel) will pick up the blocked state, surface the review request to the configured adapter, await the reply, and unblock the next stage.

## Why the protocol looks like this

The 41.77% spec-ambiguity failure mode from the MAST taxonomy is the largest cause of multi-agent breakdowns. This protocol mitigates it by:

1. **Forcing the agent to read the parent's comment thread before doing work** — context is never lost across handoffs.
2. **Mirroring artifacts to BOTH disk and kanban** — survives Hermes auto-compaction, kanban DB corruption, or filesystem loss.
3. **Stage agents never wait for humans directly** — only the orchestrator's HITL watcher does. This isolates the human-decision machinery to one place that's easy to test, swap, and audit.

## Reference

- Package root: `~/.hermes/sparc-package/`
- Templates: `~/.hermes/sparc-package/templates/<stage>.md`
- Lib: `~/.hermes/sparc-package/lib/{stages,kanban,artifacts,validators}.sh`
- Adapters: `~/.hermes/sparc-package/lib/adapters/hitl/`
- Upstream SPARC: https://github.com/ruvnet/sparc
- MAST taxonomy (failure modes): arXiv 2503.13657
