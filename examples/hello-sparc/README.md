# examples/hello-sparc

A tiny end-to-end example that exercises every part of the package: a CLI that reverses input lines, built via all 6 SPARC+Design stages.

## What it does

```
$ echo -e "hello\nworld" | reverse
olleh
dlrow
```

## How to run

From this directory, with the package installed (see the package root README):

```bash
# Initialize the SPARC pipeline in this directory
sparc init "Build a CLI that reverses input lines"

# Start the orchestrator daemon
sparc pipeline start

# Watch progress
sparc pipeline status
sparc hitl list

# When you see a [BLOCKED] task, review and respond
sparc hitl show <task-id>
sparc hitl approve <task-id>     # or: reject, redirect
```

The orchestrator will spawn stage agents in order: spec → design → pseudocode → architecture → refinement → completion. At each HITL gate (Spec, Architecture, Completion by default), it'll block and surface a review request.

## What you should see

After running `sparc init`, you should have:

- `./sparc.config.yaml` — per-project config
- 6 tasks on a Hermes Kanban board called `sparc-hello-sparc`, linked parent→child
- 7 Hermes profiles: `sparc-spec`, `sparc-design`, `sparc-pseudocode`, `sparc-architecture`, `sparc-refinement`, `sparc-completion`, `sparc-reviewer`
- 5 skills installed in `~/.hermes/skills/software-development/`

After running `sparc pipeline start`, you should see log lines like:

```
[14:23:01] sparc-pipeline started (board=sparc-hello-sparc, hitl=terminal)
[14:23:04] spawning stage agent: task=... stage=spec profile=sparc-spec skill=sparc-stage-spec
[14:23:48] HITL review request: task=... stage=spec artifact=...
```

## Files in this example

- `sparc.config.yaml` — per-project config
- `src/` — empty; the orchestrator will populate this as the pipeline runs
- `README.md` — this file

## When you're done

```bash
sparc pipeline stop
# The artifacts from each stage live in ./docs/sparc/sparc-hello-sparc/<stage>/
ls docs/sparc/sparc-hello-sparc/
```

## Adapting for your own project

Copy this directory, edit `sparc.config.yaml` to match your needs, then `sparc init "your goal here"`. The 6 stages will run with the same HITL gates you configured.
