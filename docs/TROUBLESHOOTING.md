# Troubleshooting

If `sparc doctor` is happy but something is broken, start here. If `sparc doctor` is unhappy, fix what it complains about first.

**Navigation:** [Setup / install](#setup--install) · [Profiles](#profiles) · [Skills](#skills) · [Kanban](#kanban) · [Orchestrator daemon](#orchestrator-daemon) · [HITL](#hitl) · [Artifact storage](#artifact-storage) · [Replacing the poller with events](#replacing-the-poller-with-events-advanced) · [Performance](#performance) · [Getting more help](#getting-more-help)

---

## Quick links

- **What is sparqr?** See the [README](../README.md).
- **How does it work?** See [ARCHITECTURE.md](ARCHITECTURE.md).
- **What commands are available?** See [COMMANDS.md](COMMANDS.md) — canonical CLI reference.
- **Common questions** → [FAQ.md](FAQ.md).
- **Spotted a bug?** [File an issue](https://github.com/jb-bz/sparqr/issues/new?template=bug_report.md).

---

## Setup / install

### `bash: bad substitution` when running setup.sh

Your bash is < 4.0. Install a newer one. On macOS: `brew install bash && echo /usr/local/bin/bash | sudo tee -a /etc/shells && chsh -s /usr/local/bin/bash`. On Linux: `apt install bash` (or your distro's equivalent).

### `hermes: command not found`

Install Hermes first. https://hermes-agent.nousresearch.com

### `setup.sh: 5 fail, 0 warn` from sparc doctor

The setup didn't complete. Re-run it. If it still fails, check that your Hermes version is ≥ 0.6.0 with `hermes --version`.

### `sparc not on PATH` after setup

```bash
export PATH="$HOME/.local/bin:$PATH"
# add to your shell rc to persist
```

Or set `PREFIX=/usr/local` before running setup.sh to install to `/usr/local/bin/` (requires sudo).

## Profiles

### A profile is missing after setup

Re-run `setup.sh`. Or manually:

```bash
hermes profile create sparc-spec --clone-from default
cp $SPARC_PKG_ROOT/profiles/sparc-spec.yaml ~/.hermes/profiles/sparc-spec/profile.yaml
hermes profile show sparc-spec   # verify
```

### Profile config not taking effect

Hermes reads the profile's `config.yaml` at session start. If you edit a profile while a session is open, `/reset` (or restart) for the changes to apply. For the stage agents spawned by the orchestrator, the next spawn will pick up the change.

## Skills

### A skill is missing

Re-run `setup.sh`. Or manually:

```bash
cp -R $SPARC_PKG_ROOT/skills/sparc-pipeline-orchestrator ~/.hermes/skills/software-development/
```

### Skill not auto-loading in a session

Hermes skills are loaded per-session. If a session started before the skill was installed, `/reload-skills` (in-session) or start a new session. The orchestrator's spawned agents always start fresh, so they'll have the latest skills.

## Kanban

### Board creation fails

Check the Hermes Kanban docs. Most common: a board with the same name already exists, or Hermes's storage is full.

```bash
hermes kanban boards list
hermes kanban --board <slug> list
```

### `kanban_link: command not found` or similar

The Hermes Kanban CLI verb names vary by version. The package's `lib/kanban.sh` wrappers try multiple verbs; if they all fail, check the version with `hermes --version` and consult the [Kanban docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban). You can also patch `lib/kanban.sh` for your Hermes version.

### Tasks stuck in `running` after an agent crash

The orchestrator's `kanban_set_status running` happens BEFORE the agent spawns. If the agent crashes, the task is stuck. Manually fix:

```bash
hermes kanban --board <board> set <task> --status ready
# or
sparc hitl show <task>
sparc hitl approve <task>   # or redirect
```

For a permanent fix, edit `bin/sparc-pipeline` to add a stale-task reaper:

```bash
# In the run_loop, add:
hermes kanban --board "$SPARC_BOARD" list --status running | while read line; do
  # parse task_id and pid from the line
  # if pid is dead, set back to ready
done
```

## Orchestrator daemon

### `sparc pipeline start` exits immediately

Check the log: `tail -n 50 ~/.hermes/sparc-package/logs/sparc-pipeline.log`. Common causes:
- The board name in `sparc.config.yaml` doesn't match the actual board (`hermes kanban boards list` to check)
- Hermes is not on PATH
- A syntax error in `lib/*.sh` (run `bash -n $SPARC_PKG_ROOT/lib/stages.sh` etc.)

### Daemon is running but tasks aren't advancing

The kanban comment thread is the orchestrator's context. If a stage agent's profile has `tool_use_enforcement: false` or is missing the `kanban_*` toolset, it can't read the comment thread. Check:

```bash
hermes profile show sparc-spec   # should have kanban toolset enabled
```

### Stages are re-running in a loop

Almost always a validation failure. The orchestrator re-spawns the same stage when the artifact fails the validator. Run `sparc validate <stage> <board> <task>` to see the failure reason:

```bash
source $SPARC_PKG_ROOT/lib/validators.sh
sparc_validate_specification <board> <task>
```

## HITL

### Terminal adapter is reading from the wrong TTY

The `terminal` adapter reads from `/dev/tty` (the controlling terminal). If the orchestrator is running as a background process (`sparc pipeline start`), there's no controlling TTY, so the adapter's `read -r -p "review> " reply < /dev/tty` will fail. Solutions:
- Use the `tui` adapter instead (writes to a file the human reads in their TUI)
- Use the `webui` / `workspace` / `official-dashboard` adapter
- Use the `terminal` adapter only when running `sparc pipeline run-once` in the foreground

### webui / workspace adapter says "not available"

The probe is checking a URL. Check that:
- The webui / workspace / dashboard is running
- The URL is correct (override with `SPARC_WEBUI_URL` / `SPARC_WORKSPACE_URL` / `SPARC_HITL_DASHBOARD_URL` env vars)
- No firewall blocking localhost

### Telegram / Discord / Slack notifier

Not supported in v0.1.0. The HITL adapter IS the notification — when a review is needed, you see it in whichever UI you configured. If you need a chat-gateway ping, you can either:

- Use a HITL adapter that posts to your chat gateway (hack, but works) — see [docs/HITL.md](HITL.md#adding-a-chat-gateway-notifier-today)
- Wait for v0.4.0 which will ship a proper notify channel

For chat-gateway integration today, configure your Hermes gateway the standard way (`hermes gateway setup telegram` etc.) and then add a custom HITL adapter that calls the gateway's chat-send API as part of `hitl_<name>_notify`.

## Artifact storage

### Artifacts not appearing in `./docs/sparc/`

Check `SPARC_ARTIFACT_DISK_DIR` in `sparc.config.yaml`. Default is `./docs/sparc`. The orchestrator expands `~` to `$HOME` but not other shell variables.

### Artifacts only in kanban, not on disk (or vice versa)

The `artifacts.also_kanban_comment: true` setting in `sparc.config.yaml` controls this. Set to `false` to disable kanban mirroring. (You almost never want this — the dual store is the whole point.)

## Replacing the poller with events (advanced)

The orchestrator polls every 3 seconds. If you need <1s latency, you can replace the poller with a real subscription. Hermes Kanban doesn't expose a subscribe API directly, but you can:

1. Set up a SQLite trigger on the kanban DB to write to a sidecar table on state change
2. Have the orchestrator's run loop watch the sidecar table (e.g. with `inotifywait` on the DB file or a simple polling loop on the sidecar)

This is left as an exercise; not implemented in v0.1.0. If you build it, please send a PR.

## Performance

### Pipeline is slow

- `agent.max_turns: 90` for refinement/completion is the highest in the package. Lower it for your use case.
- `terminal.timeout: 1800` (seconds, the wall-clock cap per task; 1800 seconds = half an hour). If your tasks need longer, raise it.
- The 3-second polling interval adds up to 3s of latency between stage transitions. If you need faster, see "Replacing the poller with events" above.

### Tokens are expensive

- The package uses your Hermes profile's default model. For cheaper runs, set the per-profile model in `~/.hermes/profiles/<stage>/config.yaml`:
  ```yaml
  model:
    provider: openrouter
    default: anthropic/claude-haiku-4
  ```
- Spec / Design / Pseudocode are good candidates for cheaper models. Refinement / Completion want the strongest.

## Methodology tooling (sparc story / retro / velocity)

### `sparc story add --points 7` rejects the points value
The point scale is Fibonacci: 1, 2, 3, 5, 8, 13. Other values are rejected at `add` time. If your estimate is genuinely 7, you have three options:
- Round down to 5 (most common)
- Round up to 8
- Split into two stories (5 + 2 or 3 + 5)

### `sparc config validate` warns about 13-pt stories
The 13-pt warning is by design. The methodology says: split a 13-pt story into sub-stories of 1/2/3/5/8 pts each. `sparc config validate` exits 0 (warn, don't fail) but surfaces the warning so it can't be ignored.

To split:
```bash
sparc story split my-story-1a2b3c \
    --into "Sub A" --points 5 \
    --into "Sub B" --points 8
```
The parent is marked `deferred`, the sub-stories become top-level entries linked via `parent_story`.

### `sparc retro` doesn't see my latest commits
The retro command uses `git log <prev_tag>..<release>` to detect commits. If your release tag isn't found, fall back to date-based detection (`git log --since=<CHANGELOG-date>`). If both fail, the file says "(no commit data available — fill this in by hand)."

Common cause: you tagged the release AFTER running `sparc retro`. Run retro after tagging.

### `sparc velocity` shows `?` for older releases
Pre-v0.4.1 retrospectives were hand-written without the standard format (Estimated / Actual / Velocity / Stories done / Deferred). `sparc velocity` parses the markdown but can't extract fields it doesn't find. Two options:
- Edit the old retro to include the standard fields
- Add stories for that release to `.sparc/stories.yaml` so velocity data comes from the ledger instead

### `sparc retro --dry-run` is empty
The release wasn't auto-detected from CHANGELOG. Either:
- Specify it explicitly: `sparc retro v0.5.0`
- The CHANGELOG.md doesn't have a `## [vX.Y.Z]` section yet

### Post-commit hook didn't print a reminder
The hook fires only when:
- A tag was just added at HEAD, OR
- The commit message references `vX.Y.Z`

If neither applies (e.g., normal feature commit), no reminder. To verify the hook is installed: `ls -la .git/hooks/post-commit`. To uninstall: `rm .git/hooks/post-commit`.

## Getting more help

1. `sparc doctor` — automated health check
2. `sparc --help` and `sparc <subcommand> --help` — command reference (full list at [COMMANDS.md](COMMANDS.md))
3. The log files in `~/.hermes/sparc-package/logs/`
4. The kanban DB — `sqlite3 ~/.hermes/kanban/boards/<slug>/kanban.db` to inspect
5. Re-run `sparc story list`, `sparc velocity`, `sparc config validate` to surface state issues
6. File an issue on [GitHub](https://github.com/jb-bz/sparqr/issues/new?template=bug_report.md)
