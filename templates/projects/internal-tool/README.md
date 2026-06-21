# $(PROJECT_NAME)

Internal tool scaffolded by **sparqr** using the `internal-tool` template.

## What this gives you

A SPARC+Design pipeline configured for an internal tool (something only your team uses):

- 6-stage workflow: spec → design → pseudocode → architecture → refinement → completion
- **Sampling gates throughout** (10% review rate) — internal tools iterate fast; humans review when shipped
- HITL adapter: `terminal`

## Quick start

```bash
sparc init "$(basename $(pwd))"
sparc pipeline start
sparc status
```

## Internal-tool philosophy

**Ship, then review.** Internal tools are consumed by a known audience (your team). You can fix issues after deploy. So we minimize gate overhead:

- 90% of stages auto-approve without human review
- 10% get reviewed to catch the worst bugs early
- The orchestrator moves quickly through the pipeline

If a critical bug slips through (the 90% case), fix it after deploy. The reconciler (if enabled) keeps your artifacts in sync with kanban so post-deploy inspection is easy.

## Customizing

For higher-stakes internal tools (production infra, anything that touches customer data), raise the sampling rate:

```yaml
gates:
  spec:
    type: approval       # every spec reviewed
  design:
    type: sampling
    percent: 50          # half of designs reviewed
```

For pure prototypes / spike work, lower the rates:

```yaml
gates:
  spec:
    type: exception      # only flag if reviewer finds a problem
```

## Next steps

1. Edit `sparc.config.yaml`.
2. `sparc config validate`.
3. `sparc init "$(basename $(pwd))"`.
4. `sparc pipeline start`.
