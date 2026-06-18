# Hermes SPARC Orchestration Package

> A pluggable, UI-agnostic implementation of the **SPARC+Design** methodology (Specification → Design → Pseudocode → Architecture → Refinement → Completion) for [Hermes Agent](https://hermes-agent.nousresearch.com/), with **human-in-the-loop** gates and durable coordination via Hermes Kanban.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Hermes Agent](https://img.shields.io/badge/Hermes-Agent-blueviolet)](https://hermes-agent.nousresearch.com/)
[![SPARC+Design](https://img.shields.io/badge/SPARC%2BDesign-6%20stages-orange)](docs/ARCHITECTURE.md)

## What this is

A drop-in package you import into a **running** Hermes install. It gives you:

- A **6-stage pipeline** (SPARC's 5 official phases + a Design phase you add between Specification and Pseudocode)
- **7 named profiles** in `~/.hermes/profiles/` — one per stage agent + one reviewer
- A **durable coordination substrate** built on Hermes Kanban (SQLite per-board, parent→child DAG via `task_links`)
- **Human-in-the-loop gates** at the stage boundaries (light-touch — see [HITL.md](docs/HITL.md))
- A **pluggable HITL adapter layer** so you can review from any of:
  - The Hermes TUI (`/kanban` slash command)
  - The official `hermes dashboard` (`:9119`)
  - [`nesquena/hermes-webui`](https://github.com/nesquena/hermes-webui) (`:8787`, with its built-in kanban board)
  - [`outsourc-e/hermes-workspace`](https://github.com/outsourc-e/hermes-workspace) (`:3000`, Swarm Mode Kanban TaskBoard)
  - Plain terminal prompts (fallback)

  All five ship in v0.1.0 and the setup script auto-detects which are running. A chat-gateway notifier (Telegram / Discord / Slack / Signal / email) is a separate concept and is planned for v0.2.0 — see [docs/HITL.md](docs/HITL.md) for the adapter interface so you can roll your own.
- A **`sparc` CLI** for orchestration (`sparc pipeline start`, `sparc stage spec`, `sparc doctor`, etc.)
- A **6-template artifact kit** (specification, design, pseudocode, architecture, refinement, completion)
- A **full end-to-end example** in `examples/hello-sparc/`

## What this is NOT

- **Not a fresh Hermes installer.** It does not touch `~/.hermes/config.yaml`, your API keys, your model, your skills, or your memory. It only adds to `~/.hermes/profiles/`, `~/.hermes/skills/`, and `~/.hermes/scripts/`.
- **Not a multi-agent framework.** It is a methodology + glue. The orchestrator is a small bash daemon. The agents are your existing Hermes, scoped to per-stage profiles.
- **Not an external PM tool.** It does not require Plane.so, Linear, or Jira. If you already use one of those, see [docs/HITL.md § "Mirroring to an external tool"](docs/HITL.md) for the optional mirror pattern.
- **Not a substitute for the Hermes Kanban docs.** This package assumes you have read [the canonical Kanban docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban) at least once.

## Quick start (5 minutes)

```bash
# 1. Clone
git clone https://github.com/<your-org>/hermes-sparc-package.git
cd hermes-sparc-package

# 2. Run the importer — interactive, asks 1 question, ~2 minutes
./setup.sh

# 3. Verify
sparc doctor

# 4. Try the example
cd examples/hello-sparc
sparc init "Build a CLI that reverses input lines"

# 5. Review from your preferred UI (webui / workspace / dashboard / TUI / terminal)
```

`setup.sh` will:
- Detect your Hermes version
- Create 7 profiles (`sparc-spec`, `sparc-design`, `sparc-pseudocode`, `sparc-architecture`, `sparc-refinement`, `sparc-completion`, `sparc-reviewer`)
- Install 5 skills into `~/.hermes/skills/software-development/`
- Install the `sparc` CLI into `~/.local/bin/` (or your `$PATH`)
- Probe for running HITL surfaces (hermes-webui / hermes-workspace / hermes dashboard) and let you pick one
- Run `sparc doctor` at the end so you can see the green lights

## Documentation

- **[INSTALL.md](docs/INSTALL.md)** — Detailed install walkthrough, troubleshooting, idempotency notes
- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** — How the pieces fit (orchestrator, kanban, profiles, adapters, agents)
- **[HITL.md](docs/HITL.md)** — Human-in-the-loop gates, the adapter interface, how to write a new adapter, how to mirror to an external PM tool
- **[ADDING-STAGES.md](docs/ADDING-STAGES.md)** — How to add/remove/reorder stages (it's data, not code)
- **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** — Common failure modes and fixes
- **[FAQ.md](docs/FAQ.md)** — Frequently asked questions

## Repository layout

```
package/
├── setup.sh                     # import into running Hermes
├── sparc.config.yaml.example    # per-project config
├── bin/                         # CLI (sparc, sparc-pipeline, sparc-hitl-watcher, sparc-stage, sparc-doctor)
├── lib/                         # shared bash library
│   ├── stages.sh                # stage definitions (pluggable)
│   ├── kanban.sh                # kanban_* wrapper
│   ├── artifacts.sh             # artifact storage helper
│   ├── validators.sh            # spec/arch acceptance validators
│   └── adapters/
│       ├── hitl/                # terminal, tui, webui, workspace, official-dashboard
│       └── notify/              # log, telegram (opt-in)
├── profiles/                    # 7 per-stage profile YAMLs
├── skills/                      # 5 skills for the running Hermes
├── templates/                   # 6 artifact templates
├── examples/hello-sparc/        # end-to-end working example
├── docs/                        # the docs above
├── tests/                       # shell-based test suite
├── .github/                     # issue + PR templates
├── LICENSE                      # MIT
├── CONTRIBUTING.md
├── CHANGELOG.md
└── README.md                    # you are here
```

## Requirements

- Hermes Agent >= 0.6.0 (`hermes --version`)
- Hermes Kanban enabled (it is by default since Hermes 0.1.2)
- Bash >= 4.0
- macOS or Linux (Windows: best-effort via WSL2)
- `sqlite3` CLI (preinstalled on macOS and most Linux)
- `curl` (for HITL adapter probes)
- `jq` (for JSON parsing in the orchestrator)
- One of: `hermes-webui` (optional), `hermes-workspace` (optional), built-in `hermes dashboard` (optional, ships with `hermes-agent[web,pty]`)

## Why SPARC+Design and not just SPARC?

Upstream `ruvnet/sparc` is 5 phases. The Design phase between Specification and Pseudocode is a community extension — it makes "what does this look like" a first-class review gate instead of letting it leak into Pseudocode. You can remove it with one line of config if you want pure SPARC. See [docs/ADDING-STAGES.md](docs/ADDING-STAGES.md).

## License

MIT. See [LICENSE](LICENSE).

## Acknowledgments

- The [Hermes Agent](https://hermes-agent.nousresearch.com/) team for Kanban, profiles, and skills
- [ruvnet](https://github.com/ruvnet) for the original [SPARC](https://github.com/ruvnet/sparc) methodology
- [Nesquena](https://github.com/nesquena) for the first-party `hermes-webui` and its kanban panel
- The [`hermes-workspace`](https://github.com/outsourc-e/hermes-workspace) maintainers for the Swarm Mode Kanban TaskBoard that this package can drive as a Conductor
