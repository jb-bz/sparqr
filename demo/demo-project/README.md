# sparqr demo project

This is the demo project that runs when you start the sparqr hosted
demo (`./demo/sparqr.sh up`). It's a tiny example designed to show
the pipeline end-to-end in a few seconds.

## What it does

The demo runs `sparc pipeline run-once` against a pre-configured
board (`sparqr-demo`). It exercises all 6 stages (spec → design →
pseudocode → architecture → refinement → completion) using the
sampling gate defaults so no human review is required.

## What's interesting to look at

After the demo starts:
- **http://localhost:8787** — Hermes webui. Shows the kanban board,
  tasks, comments, and artifacts.
- **http://localhost:8787 → Board: sparqr-demo** — see the 6 tasks
  linked parent→child, with their stage prefixes in the titles.
- **Container logs** — `docker compose -f demo/docker-compose.yml logs
  -f sparqr` shows the pipeline iterating through stages.

## Try this

```bash
# From the package root:
./demo/sparqr.sh up

# Wait for "Pipeline complete." in the sparqr container logs.

# Open http://localhost:8787 in your browser.
# Look at:
#   - Board: sparqr-demo
#   - Tasks: 6 tasks (one per stage), linked parent→child
#   - Comments on the spec task: the spec artifact (auto-reconciled)
#   - The 'done' state on tasks the pipeline finished

# Tear down:
./demo/sparqr.sh down
```

## Editing the demo

The mounted volume means changes to `./demo/demo-project/` show up
immediately in the container. Try editing `sparc.config.yaml` to
change gate types, then:

```bash
docker exec -it sparqr-demo-sparqr bash
cd /demo-project
sparc pipeline run-once   # see the new behavior
```

## Why sampling gates

The demo uses `sampling` gates with `percent: 0` (or 100 for spec) so
it runs without human review. In real projects you'd use
`approval` for stages where humans must sign off (most public APIs)
or `confidence` for stages where high reviewer confidence is enough.

Edit `sparc.config.yaml` to try other gate types. Run `sparc config
validate` to check your changes against the schema.
