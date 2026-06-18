---
name: sparc-stage-helpers
description: Common helpers for the Pseudocode, Architecture, Refinement, and Completion stages. Loaded by those stage profiles. Contains the per-stage discipline, validation rules, and what "good" looks like.
version: 0.1.0
author: Hermes SPARC Package
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [sparc, stage, pseudocode, architecture, refinement, completion]
    related_skills: [sparc-pipeline-orchestrator, sparc-stage-spec, sparc-stage-design, test-driven-development, systematic-debugging]
    category: software-development
---

# SPARC Stage Helpers

This skill is loaded by 4 of the 6 stage profiles (pseudocode, architecture, refinement, completion). It contains the cross-cutting discipline that all four share, plus a quick reference for what each stage must produce.

## The shared discipline

For every stage:

1. **Read upstream first.** Run `hermes kanban --board "$SPARC_BOARD" show "$TASK_ID" --comments` and read the entire comment thread. The thread carries the upstream artifacts. The orchestrator is not passing context in your prompt — you must pull it.
2. **Use the template.** `cat $SPARC_PKG_ROOT/templates/<your-stage>.md` and follow the structure exactly. Sections you skip will fail validation.
3. **Write the artifact to disk first, then publish.** The publish step mirrors to kanban. If you publish without writing to disk, you have no recoverable source of truth.
4. **Call exactly one terminal verb at the end.** Either `sparc_kanban_complete` (no review needed) or `sparc_kanban_block` (review needed). Not both. Not neither.
5. **Don't wait for humans.** If you `block`, you exit. The orchestrator's HITL watcher will surface the review.

## Per-stage quick reference

### Pseudocode

- Numbered algorithmic steps (at least 5)
- Decision points called out (`if X then Y else Z`)
- Data structures listed (with field names, not types)
- Edge cases called out (empty input, max-size input, partial failure)
- **Validation:** `sparc_validate_pseudocode` checks for ≥5 numbered steps

### Architecture

- **Components / Modules / Services** — what owns what
- **Data flow** — where data lives, how it moves, persistence choices
- **API / Interface / Contract** — exact request/response shapes if applicable
- **Technology choices with rationale** — not defaults, justified
- **Failure modes** — how each component fails and what recovers
- **Validation:** all three of Components, Data Flow, API/Interface must be present

### Refinement

- TDD-first: write failing test, then minimal code, then refactor
- Test results section in the artifact (RED → GREEN → REFACTOR phases recorded)
- Security hardening for any user-facing surface (OWASP top 10 minimum)
- Debugging: if you hit a bug, use systematic-debugging; never guess
- **Validation:** `## Test Results` section must be present

### Completion

- Full test suite run (no regressions)
- Every acceptance criterion from the Specification verified (each one crossed off)
- Success metrics checked (each one ticked)
- User-facing docs (README, usage examples, troubleshooting)
- Deployment plan (if applicable)
- Verification checklist: ≥80% of items must be `[x]` not `[ ]`
- **Validation:** `## Verification Checklist` with ≥80% complete

## When to use companion skills

| Companion | When |
|---|---|
| `test-driven-development` | Refinement stage. Strict RED-GREEN-REFACTOR. |
| `systematic-debugging` | When you hit a bug. Root cause before fix. |
| `spike` | When you need to validate an approach quickly before committing. |
| `plan` | When the stage is complex enough to warrant its own plan. |

## Cross-stage conventions

- **File paths:** relative to project root, no `~`. Absolute only when calling Hermes CLI.
- **Code blocks:** language-tagged. `\`\`\`python`, not `\`\`\``.
- **Shell commands:** include the prompt, like `bash`, `zsh`, not just `$`.
- **Status messages:** one line, imperative voice, ends with a period.
- **Decisions:** record them in the artifact with a one-paragraph rationale, not just "we decided X".

## Reference

- See `lib/validators.sh` for exact validation rules
- See `templates/<stage>.md` for full per-stage templates
- See `docs/ADDING-STAGES.md` for adding a custom stage
