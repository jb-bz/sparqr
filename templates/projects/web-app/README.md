# $(PROJECT_NAME)

Web application scaffolded by **sparqr** using the `web-app` template.

## What this gives you

A SPARC+Design pipeline configured for a web app:

- 6-stage workflow: spec → design → pseudocode → architecture → refinement → completion
- **Early stages require human approval** (spec, design, architecture)
- **Late stages auto-approve on high confidence** (refinement, completion at threshold 0.9)
- HITL adapter: `terminal` (override in `sparc.config.yaml` if you want a different one)

## Quick start

```bash
# Initialize the kanban board and tasks
sparc init "$(basename $(pwd))"

# Start the orchestrator daemon
sparc pipeline start

# Watch what's happening
sparc status
```

## Customizing

Open `sparc.config.yaml`. Most useful tweaks:

```yaml
# Use a specific model for some stages (uncomment to enable)
# models:
#   spec: anthropic/claude-haiku-4
#   refinement: anthropic/claude-sonnet-4

# Change a gate type
# gates:
#   spec:
#     type: confidence    # instead of approval
#     threshold: 0.95

# Use a different HITL adapter
# hitl_adapter: webui
```

Validate any changes with `sparc config validate`.

## Next steps

1. Edit `sparc.config.yaml` to taste.
2. Run `sparc config validate` to check for typos.
3. Run `sparc init "$(basename $(pwd))"` to create the kanban board.
4. Run `sparc pipeline start` to begin the pipeline.
