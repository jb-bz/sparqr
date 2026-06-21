# $(PROJECT_NAME)

Library scaffolded by **sparqr** using the `library` template.

## What this gives you

A SPARC+Design pipeline configured for a library (something published and consumed by other code):

- 6-stage workflow: spec → design → pseudocode → architecture → refinement → completion
- **Confidence gates throughout** — public API decisions are hard to reverse, so the review cost is worth it
- **Stricter thresholds on design and architecture** (0.95) — these stages shape the public surface
- **Completion requires human approval** — final API review before publish
- HITL adapter: `terminal`

## Quick start

```bash
sparc init "$(basename $(pwd))"
sparc pipeline start
sparc status
```

## Library-specific concerns

**API stability.** Library users depend on your public surface. The default gates reflect this — higher thresholds mean reviewers must be more confident before auto-approval. If you ship a lot of internal refactors, you can lower thresholds; if you ship to thousands of users, raise them.

**Versioning.** Sparqr doesn't version your library — that's your job (semver, calendar versioning, etc.). But it does give you a documented process for going from idea → published artifact.

## Customizing

For an experimental library, lower the design/architecture thresholds:

```yaml
gates:
  design:
    type: confidence
    threshold: 0.85    # was 0.95
  architecture:
    type: confidence
    threshold: 0.85    # was 0.95
```

For a stable v1.x library, raise them:

```yaml
gates:
  design:
    type: approval      # require human review of every API design
```

## Next steps

1. Edit `sparc.config.yaml`.
2. `sparc config validate`.
3. `sparc init "$(basename $(pwd))"`.
4. `sparc pipeline start`.
