---
name: sparc-hitl-watcher
description: Surface SPARC pipeline HITL reviews to the configured human-in-the-loop adapter (terminal, TUI, webui, workspace, or official dashboard). For the reviewer profile and the orchestrator daemon.
version: 0.1.0
author: Hermes SPARC Package
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [sparc, hitl, review, kanban]
    related_skills: [sparc-pipeline-orchestrator]
    category: software-development
---

# SPARC HITL Watcher

This skill is loaded by the `sparc-reviewer` profile and by any Hermes session that is handling human review decisions for the SPARC+Design pipeline. It teaches the agent how to surface a review request via the configured adapter and how to interpret the reply.

## When this skill loads

- The `sparc-reviewer` profile is active
- The user invokes the reviewer manually: `hermes -p sparc-reviewer chat -q "Review task X"`
- The orchestrator daemon delegates a blocked task to the reviewer

## The protocol

### 1. Confirm the configured adapter

```bash
source ~/.hermes/sparc-package/lib/adapters/hitl/_registry.sh
hitl_list_adapters
hitl_probe "$SPARC_HITL_ADAPTER" && echo "✓ adapter is reachable" || echo "✗ adapter NOT reachable"
```

If the probe fails, the user must start the relevant surface (or change `SPARC_HITL_ADAPTER` in `sparc.config.yaml`).

### 2. Read the task to be reviewed

```bash
hermes kanban --board "$SPARC_BOARD" show "$TASK_ID" --comments
```

The comment thread carries the upstream artifact and the [BLOCKED] reason from the stage agent. Read it.

### 3. Read the artifact from disk

```bash
source ~/.hermes/sparc-package/lib/artifacts.sh
sparc_artifact_latest "$SPARC_BOARD" "$STAGE"
```

Open this file and review it. Be specific. Be brief. Be kind.

### 4. Surface the review to the human

```bash
hitl_notify "$SPARC_HITL_ADAPTER" "$SPARC_BOARD" "$TASK_ID" "$STAGE" "<artifact path>"
```

### 5. Await the human's reply

```bash
hitl_await_reply "$SPARC_HITL_ADAPTER" "$SPARC_BOARD" "$TASK_ID"
```

This blocks until the human replies. The reply is one of:

- `APPROVE` (or `a` / `yes` / `y`) — gate passed, unblock
- `REDIRECT` (or `r`) — gate failed, but with guidance; rerun the stage
- `REJECT` (or `x` / `no` / `n`) — gate failed, halt the pipeline
- Any other text — treated as REDIRECT with the text as guidance

### 6. Apply the decision

```bash
source ~/.hermes/sparc-package/lib/kanban.sh

case "$REPLY" in
  APPROVE*)
    sparc_kanban_unblock "$SPARC_BOARD" "$TASK_ID" "approved: $REPLY"
    ;;
  REJECT*)
    sparc_kanban_set_status "$SPARC_BOARD" "$TASK_ID" "archived"
    sparc_kanban_comment "$SPARC_BOARD" "$TASK_ID" "[REJECTED] $REPLY"
    ;;
  *)
    # REDIRECT or free text
    sparc_kanban_comment "$SPARC_BOARD" "$TASK_ID" "[REDIRECT] $REPLY"
    sparc_kanban_set_status "$SPARC_BOARD" "$TASK_ID" "ready"
    ;;
esac
```

## What "good" looks like

A good review reply:

- **APPROVE**: just `APPROVE`, or `APPROVE: nice work, ship it`. Keep it terse; the gate is about pass/fail, not vibes.
- **REDIRECT**: must include WHAT to change. `REDIRECT: add a section on error states in the design` works. `REDIRECT: meh` does not.
- **REJECT**: must include WHY. `REJECT: scope creep, this is 3 features not 1` works. `REJECT: nope` does not.

The orchestrator will re-spawn the stage agent for REDIRECT and the re-spawned agent will read your comment as new guidance. Be specific and the next iteration will be much shorter.

## Reversibility-aware gating (advanced)

The `agentpatterns.ai/workflows/human-in-the-loop` Reversibility Frame says:

- **Gate before** actions that are irreversible (merge to main, deploy to prod, delete data, send money)
- **Skip gates for** reversible steps (write a draft, create a branch, apply a label, post a comment)
- **Over-gating defeats automation. Under-gating ships errors.**

By default this package gates only Spec, Architecture, and Completion — the three "what are we building" / "how is it structured" / "is it done" gates. Refinement and Pseudocode are skipped because their artifacts are recoverable — if the agent's pseudocode is bad, the next pseudocode pass replaces it. A failure in Completion is not recoverable (it's been deployed).

If you want to change this, edit `sparc.config.yaml`:

```yaml
hitl_gates:
  spec:         true
  design:       false
  pseudocode:   false   # set to true if you want to gate this
  architecture: true
  refinement:   false   # set to true if you want to gate this
  completion:   true
```

## Reference

- See `docs/HITL.md` for how to author new adapters
- See `lib/adapters/hitl/_registry.sh` for the adapter dispatch interface
- See `profiles/sparc-reviewer.yaml` for the reviewer profile config
