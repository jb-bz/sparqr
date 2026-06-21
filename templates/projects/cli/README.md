# $(PROJECT_NAME)

CLI tool scaffolded by **sparqr** using the `cli` template.

## What this gives you

A SPARC+Design pipeline configured for a CLI tool:

- 6-stage workflow: spec → design → pseudocode → architecture → refinement → completion
- **Early stages auto-approve on confidence** (spec, design, pseudocode, architecture at threshold 0.9)
- **Design is sampled** — only 10% of designs get human review, the rest auto-approve
- **Refinement and completion require human approval** — CLI correctness matters
- HITL adapter: `terminal`

## Quick start

```bash
sparc init "$(basename $(pwd))"
sparc pipeline start
sparc status
```

## Typical CLI workflow

```bash
# 1. Build the artifact
sparc pipeline start

# 2. Watch what's happening
sparc status --board $(basename $(pwd))

# 3. When a stage is blocked (reviewer flagged an issue or
#    confidence below threshold), the prompt will tell you
sparc pipeline run-once   # or wait for the daemon
```

## Customizing

The default gates assume "this is a real CLI tool that users will run." If you're prototyping, change `refinement` and `completion` from `approval` to `confidence` to skip the human reviews:

```yaml
gates:
  refinement:
    type: confidence
    threshold: 0.95   # higher threshold for production code
  completion:
    type: confidence
    threshold: 0.95
```

Validate with `sparc config validate`.

## Next steps

1. Edit `sparc.config.yaml`.
2. `sparc config validate`.
3. `sparc init "$(basename $(pwd))"`.
4. `sparc pipeline start`.
