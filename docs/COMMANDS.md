# Command Reference

This is the canonical reference for every `sparc` subcommand. It's
hybrid: each section has a hand-written narrative (when you'd use it,
key flags, what it does) followed by the verbatim `--help` output
for the full flag inventory.

For task-oriented walkthroughs ("I want to set up a new pipeline",
"I want to see velocity across releases"), see the docs linked at
the bottom of each section. This document is the **reference** —
organized by command, not by use case.

If you're reading this on GitHub, the `--help` blocks were captured
at the time of the v0.4.1 release. To regenerate them locally, run
`bin/sparc <command> --help`.

---

## Table of contents

- [`sparc` (top-level dispatcher)](#sparc-top-level-dispatcher)
- [`sparc init`](#sparc-init)
- [`sparc new`](#sparc-new)
- [`sparc pipeline`](#sparc-pipeline)
- [`sparc stage`](#sparc-stage)
- [`sparc hitl`](#sparc-hitl)
- [`sparc doctor`](#sparc-doctor)
- [`sparc adapters`](#sparc-adapters)
- [Notify channels (Discord / Telegram / Slack / Signal)](#notify-channels-discord--telegram--slack--signal)
- [`sparc stages`](#sparc-stages)
- [`sparc status`](#sparc-status)
- [`sparc story`](#sparc-story)
- [`sparc retro`](#sparc-retro)
- [`sparc velocity`](#sparc-velocity)
- [`sparc config`](#sparc-config)
- [`sparc reconciler`](#sparc-reconciler)
- [`sparc logrotate`](#sparc-logrotate)
- [Environment variables](#environment-variables)
- [Exit codes](#exit-codes)
- [See also](#see-also)

---

## `sparc` (top-level dispatcher)

`sparc` is a thin dispatcher. It parses the first positional argument,
maps it to a `bin/sparc-<command>` file, and `exec`s that file with the
remaining arguments. So `sparc story list` is literally
`bin/sparc-story list` after the dispatcher does its work.

This means every command in this document also runs standalone as
`bin/sparc-<command>`. Useful for shell scripting, debugging, and
when a wrapper alias would obscure things.

### Common patterns

```bash
# Setup a new pipeline
sparc init "Build a CLI that reverses input lines"

# Run the orchestrator (long-running)
sparc pipeline start

# Run once for debugging (foreground)
sparc pipeline run-once

# Observe what's happening
sparc status
sparc velocity
sparc story list

# Generate a retrospective at release time
sparc retro v0.5.0 --dry-run
sparc retro                    # auto-detect from CHANGELOG

# Validate config
sparc config validate
sparc config show
```

### Verbatim `--help`

```
sparc — Hermes SPARC+Design orchestration CLI

Usage: sparc <command> [args]

Commands:
  init        Initialize a new SPARC pipeline in the current directory
              (creates sparc.config.yaml and the kanban board)
  new         Scaffold a new project from a template (web-app / cli / library / internal-tool)
              Usage: sparc new [name] [--type TYPE]  (v0.4.0)
  pipeline    Start, stop, or check status of the orchestrator daemon
              Usage: sparc pipeline {start|stop|status|restart|run-once}
  stage       Run a single stage agent manually (debug aid)
              Usage: sparc stage <spec|design|...> <task-id>
  hitl        Manage HITL reviews from the CLI (without the daemon)
              Usage: sparc hitl {list|show|approve|reject|redirect} <task>
  doctor      Validate the package install
  adapters    List HITL adapters and notify channels
  stages      List configured stages
  status      Cross-pipeline observability (boards, counts, running, blocked)
              Usage: sparc status [--board <slug>] [--json]
  story       Manage story-point estimates per repo (v0.4.1)
              Usage: sparc story {add|list|show|update|split|rm} [args]
  retro       Auto-generate a retrospective file (v0.4.1)
              Usage: sparc retro [release] [--dry-run] [--no-surprised]
  velocity    Read retros and print a velocity table (v0.4.1)
              Usage: sparc velocity [release] [--json|--csv]
  config      Inspect and validate the sparc config file
              Usage: sparc config {validate|show|schema} [path]
  reconciler  Sync disk artifacts to kanban comment threads
              Usage: sparc reconciler {run-once|daemon|status}
  logrotate   Rotate sparc-pipeline.log when it exceeds size threshold
              Usage: sparc logrotate [LOG_DIR] [--max-size BYTES] [--keep N]
  version     Print the package version
  help        Print this help

Examples:
  sparc init "Build a CLI that reverses input lines"
  sparc pipeline start
  sparc doctor
  sparc stages

See docs/ for full documentation.
```

---

## `sparc init`

Initialize a new SPARC pipeline in the current directory. Creates a
`sparc.config.yaml` (from the project's existing config, if present,
or from a template), creates a Hermes Kanban board named after the
project, and creates 6 linked tasks (one per stage) ready for the
orchestrator.

Use this when you're starting a new project or adding SPARC workflow
to an existing project. After `sparc init`, you can run
`sparc pipeline start` to begin the orchestrator loop.

### Key behavior

- **Reads existing `sparc.config.yaml`** if present (preserves your
  customizations)
- **Honors the `board:` field** in the config (override with `$SPARC_BOARD`)
- **Creates 6 tasks** in this order: spec → design → pseudocode → architecture → refinement → completion. Each task is the parent of the next.
- **Optionally installs the post-commit hook** (v0.4.1, y/N prompt). The hook nudges you to run `sparc retro` when a release tag is added.
- **Reminds you** to start tracking story points via `sparc story add`.

### Verbatim `--help`

> (Run `bin/sparc-init --help` for current output; the command prints a
> short summary and then exits with the welcome banner.)

---

## `sparc new`

Scaffold a new project from a template. Four types are supported:
`web-app`, `cli`, `library`, `internal-tool`. Each template has a
prefilled `sparc.config.yaml` with type-appropriate gates (approval,
confidence, sampling).

Use this when you're starting a **brand-new project** (not adding
SPARC to an existing one — that's `sparc init`). The new project gets
a directory with the template, a README, a `sparc.config.yaml`, and
the kanban board pre-created.

### Examples

```bash
# Interactive: asks for name + type
sparc new

# Specify name, get prompted for type
sparc new my-cli-tool

# Non-interactive
sparc new my-cli-tool --type cli

# Use the internal-tool template (sampling throughout)
sparc new dev-tool --type internal-tool
```

### Verbatim `--help`

```
sparc new — scaffold a new project from a template (v0.4.0).

Usage: sparc new [name] [--type web-app|cli|library|internal-tool]

Arguments:
  [name]                 project name (the directory will be named this)
  --type TYPE            one of web-app, cli, library, internal-tool
                         (default: prompt interactively)

Templates ship with a prefilled sparc.config.yaml. The gate policy
is type-appropriate:
  - web-app:     approval (early) + confidence (late), strict
  - cli:         confidence throughout
  - library:     confidence throughout, stricter thresholds (0.95)
  - internal-tool: sampling throughout (10% review rate)

Examples:
  sparc new my-cli --type cli
  sparc new my-service --type web-app
```

---

## `sparc pipeline`

The orchestrator daemon. Runs an event loop that watches the Hermes
Kanban board, picks up ready tasks, runs the corresponding stage
agent (via `hermes chat`), and posts the artifact back to the kanban
comment thread.

### Subcommands

- `start` — Launch the daemon in the background (or daemonize, depending on platform)
- `stop` — Stop a running daemon
- `status` — Is the daemon running? (looks for the PID file at `~/.sparc/sparc-pipeline.pid`)
- `restart` — Stop + start
- `run-once` — Run a single iteration, foreground. Useful for debugging and CI.

### When to use `run-once`

`run-once` is the right tool when:

- You're debugging a single stage and don't want the full daemon loop
- You're running in CI and want deterministic, single-iteration behavior
- You want to verify a config change works before letting the daemon run unattended

### Verbatim `--help`

```
sparc pipeline — control the orchestrator daemon.

Usage: sparc pipeline {start|stop|status|restart|run-once}

  start     Launch the orchestrator daemon (writes ~/.sparc/sparc-pipeline.pid)
  stop      Stop a running daemon
  status    Print whether the daemon is running
  restart   Stop then start
  run-once  Run a single iteration, foreground (debug aid / CI)

The daemon watches the kanban board at the configured poll interval,
picks up tasks whose parent is done, runs the appropriate stage
agent, and posts the artifact back to the kanban comment thread.
run-once is the same loop body without the daemon wrapper — useful
for catching config errors before going unattended.

Examples:
  sparc pipeline start       # background loop
  sparc pipeline status      # check if it's running
  sparc pipeline run-once    # one iteration, foreground
```

---

## `sparc stage`

Run a single stage agent manually. Useful for:

- Re-running a stage that failed in the daemon
- Running a stage before the daemon starts (to bootstrap)
- Debugging an artifact that came out wrong

The stage agent is the same one the daemon would run — it reads the
parent task's comment thread, fetches the upstream artifact, invokes
the appropriate `sparc-stage-<stage>` skill via Hermes chat, and
posts the result.

### Key flags

- `<stage>` — one of: `spec`, `design`, `pseudocode`, `architecture`, `refinement`, `completion`
- `<task-id>` — the kanban task ID (e.g., `t_abc123`)
- `--profile` — override the Hermes profile (default: from config)
- `--model` — override the model (default: from config)

### Verbatim `--help`

```
sparc stage — run a single stage agent manually.

Usage: sparc stage <stage-name> <task-id>

Stages (in order):
  spec, design, pseudocode, architecture, refinement, completion

The stage reads the parent task's comment thread, fetches the
upstream artifact, invokes the sparc-stage-<stage> skill via
Hermes chat, and posts the result back to the kanban.

Examples:
  sparc stage spec t_abc123           # run the spec stage for this task
  sparc stage design t_def456         # design stage
  sparc stage architecture t_ghi789   # architecture stage
```

---

## `sparc hitl`

Manage HITL reviews from the CLI, **without** the daemon. The daemon
normally handles HITL via the configured adapter (terminal, webui,
workspace, etc.); this command lets you do the same work manually:

- `list` — show all tasks currently waiting for review
- `show <task>` — show the review request for a task
- `approve <task>` — approve a blocked task
- `reject <task>` — reject with a reason
- `redirect <task>` — redirect the task to a different agent

Use this when the daemon isn't running but you need to clear pending
reviews, or when you want to bypass the configured adapter and
review from the CLI directly.

### Verbatim `--help`

```
sparc hitl — manage HITL reviews from the CLI.

Usage: sparc hitl {list|show|approve|reject|redirect} [args]

  list                       Show tasks currently blocked on HITL
  show <task-id>             Show the review request for a task
  approve <task-id>          Approve a blocked task
  reject  <task-id> --reason "<why>"   Reject with a reason
  redirect <task-id> --to <agent>       Redirect to a different agent

The HITL adapter configured in sparc.config.yaml (terminal / webui /
workspace / official-dashboard / tui) is the normal path. This
command is the bypass — useful when the adapter is unreachable or
you want to review from the CLI directly.

Examples:
  sparc hitl list
  sparc hitl show t_abc123
  sparc hitl approve t_abc123
  sparc hitl reject t_abc123 --reason 'API needs more detail'
```

---

## `sparc doctor`

Validate the package install. Checks:

- `bin/sparc-*` files are executable and parse
- All `lib/*.sh` files source without bash 3.2 errors
- `sparc.config.yaml` (if present) parses and validates against the schema
- Hermes daemon is reachable via `hermes kanban boards list`
- Python dependencies (`jsonschema`, `pyyaml`) are installed

If something's wrong, `doctor` tells you what. If something's right,
it stays quiet.

### Verbatim `--help`

```
sparc doctor — validate the package install.

Runs a battery of checks: bash parse of all bin/* and lib/*,
sparc.config.yaml schema validation (if present), Hermes daemon
reachability, Python dependency presence. Quiet on success; verbose
on failure.

No flags.
```

---

## `sparc adapters`

List the HITL adapters **and notify channels** that are bundled with
the package. Read-only — just enumerates `lib/adapters/hitl/*.sh` and
`lib/adapters/notify/*.sh` and probes their availability.

Use this to see what's available before editing `sparc.config.yaml`
to point `hitl_adapter:` at one, or before setting env vars to enable
a notify channel.

### Verbatim `--help`

```
sparc adapters — list bundled HITL adapters and notify channels.

Bundled HITL adapters (lib/adapters/hitl/*.sh):
  terminal          stdin/stdout (always works, fallback)
  tui               Hermes TUI /kanban slash command
  webui             nesquena/hermes-webui on :8787
  workspace         outsourc-e/hermes-workspace on :3000
  official-dashboard  hermes dashboard on :9119

Bundled notify channels (lib/adapters/notify/*.sh):
  log               write notifications to sparc-pipeline.log (always on)
  kanban            post notifications as kanban comments (always on)
  discord           Discord webhook (DISCORD_WEBHOOK_URL)
  telegram          Telegram bot API (TELEGRAM_BOT_TOKEN + TELEGRAM_CHAT_ID)
  slack             Slack incoming webhook (SLACK_WEBHOOK_URL)
  signal            signal-cli REST API (SIGNAL_API_URL + SIGNAL_RECIPIENT)

For HITL adapter details, see docs/HITL.md. For notify channel
setup, see "Notify channels" below.
```

---

## Notify channels (Discord / Telegram / Slack / Signal)

sparqr has 6 built-in notify channels. When the orchestrator's HITL
review is requested, every available channel fires the same
notification (one broadcast, multiple sends).

| Channel | Always-on? | Auth | What it does |
|---------|------------|------|--------------|
| `log` | ✅ | none | Appends to `~/.hermes/sparc-package/logs/notify.log` |
| `kanban` | ✅ | none | Posts a comment to a `sparqr-notify` task on the same board |
| `discord` | auto | `DISCORD_WEBHOOK_URL` | Posts an embed to a Discord channel via webhook |
| `telegram` | auto | `TELEGRAM_BOT_TOKEN` + `TELEGRAM_CHAT_ID` | Sends a message via Telegram Bot API |
| `slack` | auto | `SLACK_WEBHOOK_URL` | Posts Block Kit message to a Slack channel via incoming webhook |
| `signal` | auto | `SIGNAL_API_URL` + `SIGNAL_RECIPIENT` | Sends via signal-cli REST daemon (must be running) |

"auto" means: enabled automatically when the credentials are in the env.
"Always-on" means: no credentials needed, always fires.

### Setup

**Discord** (easiest):

1. Server Settings → Integrations → Webhooks → New Webhook
2. Copy the webhook URL
3. `export DISCORD_WEBHOOK_URL='https://discord.com/api/webhooks/...'` in `~/.hermes/.env`

**Telegram:**

1. Message [@BotFather](https://t.me/BotFather) → `/newbot` → get the token
2. Send `/start` to your bot (so it can message you)
3. Get your chat ID: message [@userinfobot](https://t.me/userinfobot), it replies with your numeric ID
4. `export TELEGRAM_BOT_TOKEN=...` and `export TELEGRAM_CHAT_ID=...` in `~/.hermes/.env`

**Slack:**

1. [api.slack.com/messaging/webhooks](https://api.slack.com/messaging/webhooks) → Create your Slack app → Incoming Webhooks → Add to channel
2. Copy the webhook URL
3. `export SLACK_WEBHOOK_URL='https://hooks.slack.com/services/...'` in `~/.hermes/.env`

**Signal:**

1. Install [signal-cli](https://github.com/AsamK/signal-cli)
2. Register: `signal-cli -u +1XXX register` (one-time)
3. Start the daemon: `signal-cli -u +1XXX daemon --http enabled` (must be running on the API URL)
4. `export SIGNAL_API_URL=http://127.0.0.1:8080` and `export SIGNAL_RECIPIENT=+1XXX` in `~/.hermes/.env`

### Restricting channels

By default, all available channels fire. To restrict (e.g., a CI project that shouldn't ping Telegram), add to `sparc.config.yaml`:

```yaml
notify:
  channels: [log, kanban, discord]  # only these
  events:   [hitl-review]            # only this event type
```

### Coexistence with the Hermes gateway's chat platforms

The Hermes gateway has its own messaging platforms (Telegram, Discord, Slack, Signal) under `gateway.platforms.*` — these are for **bidirectional agent chat** (the user DMs the agent, the agent DMs back). sparqr's notify channels are **one-way push** (the pipeline posts a notification, no reply expected). They use the same env vars (`TELEGRAM_BOT_TOKEN`, `DISCORD_WEBHOOK_URL`, etc.) but different endpoints (`/sendMessage` for one-way, `/getUpdates` for bidirectional). Same bot, no conflict.

### Events

In v0.4.0, only `hitl-review` events fire notifications. The planned
`stage-done` and `stage-failed` events are deferred to v0.4.1.

### Manually send a notification

```bash
# Source the registry (in a script)
source $PKG/lib/adapters/notify/_registry.sh

# Send a one-off to one channel
notify_send discord "Test" "Hello from sparqr" "https://example.com"

# Broadcast to all available channels
notify_broadcast "Test" "Hello everyone" ""
```

---

## `sparc stages`

List the configured stages in pipeline order. Each stage has:

- A **profile** (Hermes profile name; e.g., `sparc-spec`)
- A **skill** (`sparc-stage-<name>`; e.g., `sparc-stage-spec`)
- A **HITL flag** — `[HITL]` if a gate applies

This is the canonical reference for what the pipeline does. Use it
when you're not sure whether a stage is approval-gated or
auto-approved.

### Example output

```
$ sparc stages
Configured stages (in order):
  1. Specification [HITL]  profile=sparc-spec           skill=sparc-stage-spec
  2. Design                profile=sparc-design         skill=sparc-stage-design
  3. Pseudocode            profile=sparc-pseudocode     skill=sparc-stage-helpers
  4. Architecture  [HITL]  profile=sparc-architecture   skill=sparc-stage-helpers
  5. Refinement            profile=sparc-refinement     skill=sparc-stage-helpers
  6. Completion    [HITL]  profile=sparc-completion     skill=sparc-stage-helpers
```

### Verbatim `--help`

```
sparc stages — list configured stages.

Stages are read from lib/stages.sh. Each has a profile (Hermes),
a skill (sparc-stage-<name>), and an optional HITL gate. Output
includes a [HITL] marker for stages with a non-default gate.
```

---

## `sparc status`

Cross-pipeline observability. Shows:

- All kanban boards (top-level summary)
- Per-board task counts: total / ready / running / blocked / done
- Currently running tasks
- Blocked tasks (waiting for HITL)

Slow (calls `hermes kanban boards list` and friends). Use this when
you want a quick health check; use `sparc pipeline status` if you
only want to know whether the daemon is running.

### Key flags

- `--board <slug>` — show details for one board only
- `--json` — machine-readable output (for scripts / dashboards)

### Verbatim `--help`

```
sparc status — cross-pipeline observability.

Usage: sparc status [--board <slug>] [--json]

Default output: per-board summary with totals (todo / ready /
running / blocked / done). With --board, shows individual task rows.
With --json, outputs structured data for tooling.

Calls `hermes kanban boards list` under the hood — can be slow if
the Hermes daemon is busy.

Examples:
  sparc status                  # all boards
  sparc status --board sparqr-demo
  sparc status --json            # machine-readable
```

---

## `sparc story`

Manage story-point estimates per repo. (v0.4.1)

Stories live in `.sparc/stories.yaml` (per-repo, auto-created on
first `add`). Each story has:

- `id` — slug + hash, stable
- `name` — human-readable
- `points` — Fibonacci 1/2/3/5/8/13
- `status` — `planned`, `in-progress`, `done`, or `deferred`
- `release` — which version this story is for
- `notes` — free-form

### The 13-pt rule

A 13-pt story is a code smell. The methodology says: **split it**.
`add` with `--points 13` emits a warning + split reminder, but
doesn't block. `config validate` warns on 13-pt stories in
`planned`/`in-progress` status (warn-don't-fail, exits 0). Use
`split` to break it into sub-stories.

### Subcommands

| Sub | Purpose |
|-----|---------|
| `add <name> --points N [--status S] [--release R] [--notes ...]` | Register a story |
| `list` | Show all stories, grouped by release |
| `show <id>` | Show one story's full details |
| `update <id> [--points N] [--status S] [--notes ...]` | Update fields |
| `split <id> --into N1 --points P1 [--into N2 --points P2 ...]` | Break a 13-pt story into sub-stories |
| `rm <id>` | Delete a story |

### Examples

```bash
# Add stories at the start of a release
sparc story add "Set up CI" --points 3 --release v0.5.0
sparc story add "Notify channels" --points 5 --release v0.5.0 --status in-progress
sparc story add "Big dashboard rework" --points 13 --release v0.5.0
#   ⚠ WARNING: 13-pt stories must be split per sparqr methodology.
#   Use: sparc story split <id> --into '...' --points 5 ...

# See what you've planned
sparc story list
# ID                                   PTS  STATUS         NAME
# v0.5.0  (0/21 pts done)
#   set-up-ci-abc123                     3  ◻ planned      Set up CI
#   notify-channels-def456               5  ▶ in-progress  Notify channels
#   big-dashboard-ghi789                13  ◻ planned      Big dashboard rework

# Update progress
sparc story update notify-channels-def456 --status done

# Split the 13-pt story
sparc story split big-dashboard-ghi789 \
    --into "Dashboard API" --points 5 \
    --into "Dashboard UI"  --points 8
#   ✓ big-dashboard-ghi789 split into 2 sub-stories
#     - dashboard-api-xxx  [5 pts]  Dashboard API
#     - dashboard-ui-xxx   [8 pts]  Dashboard UI

# Remove a story
sparc story rm set-up-ci-abc123
```

### Verbatim `--help`

```
sparc story — manage story-point estimates per repo.

Usage: sparc story <subcommand> [args]

Subcommands:
  add <name> --points N     Register a new story (Fibonacci 1/2/3/5/8/13)
  list                       List all stories grouped by release
  show <id>                  Show one story's details
  update <id> [--points N]   Update a story's points/status/notes
       [--status S]
       [--notes "..."]
  split <id> --into N1 --points P1   Mark a 13-pt story as split into
             [--into N2 --points P2 ...]   sub-stories
  rm <id>                    Delete a story

The 13-pt rule:
  A 13-pt story is a code smell. The sparqr methodology requires
  it be split into sub-stories of 1/2/3/5/8 pts each. `sparc story add`
  with --points 13 emits a warning; `sparc config validate` warns on
  any 13-pt story that's still in `planned` or `in-progress` status.

Storage:
  Stories live in .sparc/stories.yaml (per-repo, not global). The
  file is auto-created on first `add` if missing. By default it's
  committed to git so velocity tracking survives across sessions,
  but teams can add `.sparc/` to .gitignore for local-only.

Examples:
  sparc story add "Set up CI" --points 3
  sparc story add "Sparc new command" --points 5 --release v0.4.0
  sparc story add "Notify channels" --points 5 --status in-progress
  sparc story list
  sparc story show notify-channels-1a2b3c
  sparc story update notify-channels-1a2b3c --status done
  sparc story split my-story-1a2b3c --into "Sub A" --points 5 --into "Sub B" --points 8
```

---

## `sparc retro`

Auto-generate a retrospective file. (v0.4.1)

Outputs to `docs/retrospectives/<release>.md` (or `<release>-WIP.md`
to avoid clobbering finalized retros).

### What gets auto-populated

| Section | Source |
|---------|--------|
| `What we said we'd do` | ROADMAP.md release summary |
| `What we actually shipped` | `.sparc/stories.yaml` (velocity data) |
| `What surprised us` | git log between previous and current release tag (real prose, not boilerplate) |
| `What we'd do differently` | Templated — fill in or accept the auto-generated hints |
| `Implications for next release` | Templated — fill in or accept the auto-generated hints |

### Key flags

- `[release]` — which version to retro (e.g., `v0.5.0`); defaults to the latest CHANGELOG entry
- `--dry-run` — print to stdout instead of writing a file
- `--no-surprised` — skip the auto-generated "What surprised us" section

### The "What surprised us" headline feature

This is the most useful part of `sparc retro`. It analyzes commit
messages between the previous release tag and the current one,
detecting:

- **Bug fixes** ("fix", "bug", "broken", "crash" in commit messages)
- **Documentation work** ("docs", "readme", "retro", "comment")
- **Performance work** ("perf", "fast", "optim", "cache")
- **Dependency updates** ("package.json", "requirements", "lib/bash3")
- **Test coverage gaps** (commits with no test references)

The output is real prose generated from your actual git history. Not
boilerplate. The user doesn't write the surprising-us section —
`sparc retro` does, and you review/edit.

### Examples

```bash
# Scaffold this release's retro (defaults to latest CHANGELOG entry)
sparc retro

# Specify the release explicitly
sparc retro v0.5.0

# Preview to stdout before writing
sparc retro v0.5.0 --dry-run

# Skip the auto-prose
sparc retro v0.5.0 --no-surprised
```

### Verbatim `--help`

```
sparc retro — auto-generate a retrospective file.

Usage: sparc retro [release] [--dry-run] [--no-surprised]

If no release is specified, defaults to the current package version
(or v0.4.0 if VERSION isn't set).

Output: docs/retrospectives/<release>.md (or .WIP.md if file exists)

What gets auto-generated:
  - Header (release, ship date, velocity data)
  - "What we said we'd do"           (from ROADMAP)
  - "What we actually shipped"       (from .sparc/stories.yaml)
  - "What surprised us"              (analyzed from git log; --no-surprised
                                    to disable)
  - "What we'd do differently"       (templated; user fills in or
                                    sparqr pre-fills from failed stories)
  - "Implications for next release"  (templated; user fills in)

The file is meant to be a starting point. Read it, edit it, commit it.
```

---

## `sparc velocity`

Read all retrospectives and print a velocity table. (v0.4.1)

### Output columns

| Column | Meaning |
|--------|---------|
| `RELEASE` | version (e.g., `v0.5.0`) |
| `EST` | estimated points (from ROADMAP) |
| `ACTUAL` | actual points shipped (from retro or stories) |
| `RATIO` | actual/estimated (1.00 = on target, <1 = under, >1 = over) |
| `DONE/TOTAL` | stories done / stories total |
| `DEF` | stories deferred |
| `NOTES` | "on target" / "under" / "over" |

### Output formats

- `table` (default) — human-readable
- `--json` — machine-readable
- `--csv` — for spreadsheets

### Filter

`sparc velocity [release]...` — only show the specified releases.

### Verbatim `--help`

```
sparc velocity — read retrospectives and print a velocity table.

Usage: sparc velocity [release...] [--json|--csv]

If no release is specified, reads all docs/retrospectives/v0.*.md.

For each release, shows:
  - Estimated / Actual / Velocity ratio
  - Stories done / deferred

Output formats:
  table  (default; human-readable)
  json   (machine-readable)
  csv    (for spreadsheets)

Data sources (in priority order):
  1. docs/retrospectives/<release>.md front-matter
  2. "What we actually shipped" section in the retro
  3. .sparc/stories.yaml (filtered by release)
  4. ROADMAP.md (estimated only)
```

---

## `sparc config`

Inspect and validate the sparc config file.

### Subcommands

- `validate [path]` — parse + schema-validate. After validation, also reads `.sparc/stories.yaml` and **warns on 13-pt stories** in `planned`/`in-progress` status (warn-don't-fail, exits 0).
- `show [path]` — print the resolved config (board, HITL adapter, profiles, models, gates)
- `schema` — print the path to the JSON schema

### Verbatim `--help`

```
sparc config — inspect and validate the sparc config file.

Usage: sparc config {validate|show|schema} [path]

  validate [path/to/sparc.config.yaml]
              Parse + schema-validate. Also reads .sparc/stories.yaml
              and warns on 13-pt stories in planned/in-progress.
  show [path]  Print the resolved config (board, hitl_adapter,
              profiles per stage, models per stage, gates per stage).
  schema       Print the path to the JSON schema file.

Examples:
  sparc config validate
  sparc config validate ./sparc.config.yaml
  sparc config show
  sparc config show examples/tutorial/sparc.config.yaml
```

---

## `sparc reconciler`

Sync disk artifacts to kanban comment threads. The orchestrator
posts an artifact to the comment thread when it finishes a stage,
but if the daemon crashes mid-stage or the network blips, an
artifact might be on disk without a corresponding kanban comment.

The reconciler walks `docs/sparc/<board>/<stage>/<task>.md` and posts
any artifact that doesn't already have a matching comment. Idempotent.

### Subcommands

- `run-once` — one pass, foreground
- `daemon` — runs as a long-running daemon (polls every N seconds)
- `status` — is the daemon running?

### Verbatim `--help`

```
sparc reconciler — sync disk artifacts to kanban comment threads.

Usage: sparc reconciler {run-once|daemon|status}

  run-once  Single pass: walk docs/sparc/, find artifacts without
            matching comments, post them. Idempotent.
  daemon    Long-running; same loop, configurable interval.
  status    Is the daemon running?

Use after a crashed orchestrator session to recover dropped comments.
Use after editing an artifact on disk (rare) to refresh the thread.

Examples:
  sparc reconciler run-once
  sparc reconciler daemon
  sparc reconciler status
```

---

## `sparc logrotate`

Rotate `sparc-pipeline.log` when it exceeds a size threshold. Keeps
the last N rotations.

### Key flags

- `[LOG_DIR]` — directory to operate in (default: `~/.sparc/`)
- `--max-size BYTES` — rotate when the log exceeds this size (default: 10 MB)
- `--keep N` — keep the last N rotated logs (default: 5)

### Verbatim `--help`

```
sparc logrotate — rotate sparc-pipeline.log when it exceeds size.

Usage: sparc logrotate [LOG_DIR] [--max-size BYTES] [--keep N]

Default LOG_DIR is ~/.sparc/ (where the pipeline writes logs).
Rotated files are named sparc-pipeline.log.1, .2, etc.

Examples:
  sparc logrotate                          # ~/.sparc/, 10MB, keep 5
  sparc logrotate /var/log/sparc --max-size 50000000 --keep 10
```

---

## Environment variables

| Var | Set by | Purpose |
|-----|--------|---------|
| `HERMES_HOME` | user / installer | Path to Hermes's home directory (default: `~/.hermes`) |
| `SPARC_BOARD` | user | Override the kanban board (overrides `board:` in config) |
| `SPARC_KANBAN_LOADED`, etc. | package | Sentinel vars to prevent double-loading of `lib/*.sh` |
| `PATH` | user / installer | Should include `/path/to/sparqr/bin/` for the `sparc` dispatcher |

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Generic failure (file not found, parse error, etc.) |
| `2` | Invalid usage (bad flags, missing args) |
| `3` | Hermes daemon unreachable |
| `4` | Config validation failed (only for `sparc config validate`) |

`config validate` warns on 13-pt stories but exits 0. Schema-validation
failures exit 4 (build-blocking). Other commands exit non-zero only
when the underlying action fails.

---

## See also

- **[README.md](../README.md)** — top-level entry, quick start, screenshots
- **[INSTALL.md](INSTALL.md)** — installation
- **[FAQ.md](FAQ.md)** — common questions, roadmap
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** — common errors
- **[HITL.md](HITL.md)** — choosing a HITL adapter
- **[ARCHITECTURE.md](ARCHITECTURE.md)** — internal architecture (for contributors)
- **[screenshots/README.md](screenshots/README.md)** — image index
- **[screenshots/workspace/README.md](screenshots/workspace/README.md)** — hermes-workspace screenshots
- **[../examples/tutorial/README.md](../examples/tutorial/README.md)** — end-to-end tutorial walkthrough
- **[../ROADMAP.md](../ROADMAP.md)** — release-by-release planning