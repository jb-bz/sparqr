<div align="center">

# ⚡️ sparqr

### SPARC+Design orchestration for [Hermes Agent](https://hermes-agent.nousresearch.com/)

*6-stage pipeline. Pluggable human-in-the-loop. Durable coordination via Hermes Kanban. Quick to install — see [Quick start](#-quick-start).*

<br>

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Hermes Agent](https://img.shields.io/badge/Hermes-%E2%89%A50.6.0-blueviolet)](https://hermes-agent.nousresearch.com/)
[![SPARC+Design](https://img.shields.io/badge/SPARC%2BDesign-6%20stages-orange)](docs/ARCHITECTURE.md)
[![Bash](https://img.shields.io/badge/Bash-%E2%89%A54.0-4EAA25.svg)](https://www.gnu.org/software/bash/)
[![macOS+Linux](https://img.shields.io/badge/macOS%20%2B%20Linux-tested-success)](https://github.com/jb-bz/sparqr/actions)
[![Tests](https://img.shields.io/badge/tests-111%20passing-brightgreen)](tests/)
[![PRs welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

</div>

---

## ✨ What is this?

**sparqr** is a small, focused package that turns [Hermes Agent](https://hermes-agent.nousresearch.com/) into a 6-stage autonomous software development pipeline. It's the methodology of [SPARC](https://github.com/ruvnet/sparc) (Specification → Pseudocode → Architecture → Refinement → Completion) plus a Design phase, made practical with **pluggable human-in-the-loop review gates** and **durable coordination via Hermes Kanban**.

You install it once, run `sparc init "build something"` in any project, and Hermes agents start producing spec → design → pseudo → arch → code → test artifacts in order, with a human review gate at the points that matter.

```
  $ sparc pipeline start
  ✓ started (PID 78492)

  [14:23:01] sparc-pipeline started (board=sparc-my-app, hitl=webui)
  [14:23:04] spawning stage agent: task=T-001 stage=spec profile=sparc-spec skill=sparc-stage-spec
  [14:23:48] HITL review request: task=T-001 stage=spec artifact=./docs/sparc/spec/T-001.md
```

---

## 🛸 Why sparqr?

The hard part of multi-agent software development is **not** getting agents to do things — it's preventing them from doing the **wrong** things. The MAST taxonomy (NeurIPS 2025) found that **41.77% of multi-agent failures are specification issues**. SPARC's 6-stage pipeline with explicit human gates is the proven mitigation. sparqr is the implementation.

> **SPARC** is the methodology. **Hermes Kanban** is the substrate. **sparqr** is the orchestrator that ties them together with a human-in-the-loop review surface of your choice.

sparqr vs. the alternatives:

| | **sparqr** | AutoGen | CrewAI | LangGraph | Ruflo/SPARC |
|---|---|---|---|---|---|
| Built for Hermes | ✅ | ❌ | ❌ | ❌ | ❌ |
| Reversibility-aware HITL | ✅ | ⚠️ | ⚠️ | ✅ | ⚠️ |
| Stage gates (not free-form) | ✅ | ❌ | ❌ | ❌ | ✅ |
| 5 HITL UI surfaces built in | ✅ | ❌ | ❌ | ❌ | ❌ |
| Self-hosted, no SaaS | ✅ | ✅ | ✅ | ✅ | ✅ |
| Single-file CLI install | ✅ | ❌ | ❌ | ❌ | ❌ |
| Bash, 200 lines of orchestrator | ✅ | ❌ (Python) | ❌ (Python) | ❌ (Python) | ❌ (TS) |
| Maintained in 2026 | ✅ | ⚠️ (Microsoft absorbed it) | ✅ | ✅ | ✅ |

---

## 🖼️ Screenshots

> *Coming soon.* Real screenshots of `sparc pipeline start` in action, the kanban board populated with stage tasks, and a sample HITL review in [hermes-webui](https://github.com/nesquena/hermes-webui) will land in `docs/screenshots/` once we record them. If you want to contribute screenshots from your own setup, see [CONTRIBUTING.md](CONTRIBUTING.md).

In the meantime, here's what the terminal output looks like:

```
$ sparc pipeline start
  → starting sparc-pipeline (logs: /Users/you/.hermes/sparc-package/logs/sparc-pipeline.log)
  ✓ started (PID 78492)

$ tail -f /Users/you/.hermes/sparc-package/logs/sparc-pipeline.log
[14:23:01] sparc-pipeline started (board=sparc-my-app, hitl=webui)
[14:23:04] spawning stage agent: task=T-001 stage=spec profile=sparc-spec
[14:23:48] HITL review request: task=T-001 stage=spec artifact=./docs/sparc/spec/T-001.md
```

---

## 🚀 Quick start

```bash
# 1. Clone
git clone https://github.com/jb-bz/sparqr.git
cd sparqr

# 2. Run the importer (asks 1 question; the package-side install is fast, but
#    the prerequisites — Hermes + Bitwarden Secrets Manager + a GitHub PAT —
#    are the slow part. See [INSTALL.md](docs/INSTALL.md) for the full story.)
./setup.sh

# 3. Verify
sparc doctor

# 4. Try the example end-to-end
cd examples/hello-sparc
sparc init "Build a CLI that reverses input lines"
sparc pipeline start

# 5. Review from your preferred UI
#    (webui / workspace / dashboard / TUI / terminal)
```

`setup.sh` will:
- ✅ Detect your Hermes version
- ✅ Create 7 profiles (6 stage agents + 1 reviewer)
- ✅ Install 5 skills into `~/.hermes/skills/software-development/`
- ✅ Install the `sparc` CLI into `~/.local/bin/`
- ✅ Probe for running HITL surfaces and let you pick one
- ✅ Run `sparc doctor` so you can see the green lights

---

## 🏛️ The 6 stages

```
          ┌─────────────┐
          │ Specification│ → user stories, acceptance criteria, success metrics
          └──────┬──────┘
                 ▼
          ┌─────────────┐
          │    Design    │ → user flows, visual design, components  ★ community extension
          └──────┬──────┘
                 ▼
          ┌─────────────┐
          │  Pseudocode  │ → numbered algorithmic steps, decision points
          └──────┬──────┘
                 ▼
          ┌─────────────┐
          │ Architecture │ → components, data flow, API contracts
          └──────┬──────┘
                 ▼
          ┌─────────────┐
          │ Refinement   │ → TDD implementation, debugging, security
          └──────┬──────┘
                 ▼
          ┌─────────────┐
          │  Completion  │ → verification, docs, deployment
          └─────────────┘

   ▲                                              ▲
   │         HITL gate (configurable)             │
   └──── Spec ✓  Arch ✓  Complete ✓ ──────────────┘
```

Each stage:
- **Reads upstream context** from the kanban comment thread (no lost handoffs)
- **Writes its artifact** to both disk and kanban (dual-store, survives anything)
- **Calls exactly one terminal verb** at the end: `sparc_kanban_complete` (no review) or `sparc_kanban_block` (human review needed)

The Design phase is a community extension to upstream SPARC's 5 phases. It makes "what does this look like" a first-class review gate. Skip it with one line in `sparc.config.yaml` if you want pure SPARC.

---

## 🎛️ Human-in-the-loop, your way

The HITL surface is pluggable. Five ship in v0.1.0:

| Adapter | Surface | When to use |
|---|---|---|
| `terminal` | In-CLI prompts | Always available, zero setup |
| `tui` | File-based, picked up by Hermes TUI `/kanban` | When you have a TUI session open |
| `webui` | [`nesquena/hermes-webui`](https://github.com/nesquena/hermes-webui) on `:8787` | You do most work in the webui |
| `workspace` | [`outsourc-e/hermes-workspace`](https://github.com/outsourc-e/hermes-workspace) on `:3000` | You want the dedicated Kanban TaskBoard |
| `official-dashboard` | Built-in `hermes dashboard` on `:9119` | Fallback when nothing else is running |

Pick at setup time. Change later with one line in `sparc.config.yaml`. Author new adapters — see [docs/HITL.md](docs/HITL.md).

Default gate placement follows the [reversibility-aware heuristic](https://agentpatterns.ai/workflows/human-in-the-loop) from agentpatterns.ai: gate Spec (irreversible commitment), Architecture (foundation), and Completion (ship decision). Skip Design / Pseudocode / Refinement (easily redone). Configurable per project.

---

## 🧰 What's in the box

```
sparqr/
├── setup.sh                          # imports into running Hermes (one question)
├── sparc.config.yaml.example         # per-project config
├── bin/                              # 6 CLI scripts
│   ├── sparc                         #   top-level dispatcher
│   ├── sparc-init                    #   create a project's pipeline
│   ├── sparc-pipeline                #   orchestrator daemon (the heart)
│   ├── sparc-stage                   #   run one stage by hand
│   ├── sparc-hitl-watcher            #   manual HITL management
│   └── sparc-doctor                  #   9-point health check
├── lib/                              # bash library
│   ├── stages.sh                     #   stage table (data, not code)
│   ├── kanban.sh                     #   kanban verb wrappers
│   ├── artifacts.sh                  #   dual-store artifact policy
│   ├── validators.sh                 #   stage-transition validators
│   └── adapters/hitl/                #   5 pluggable HITL adapters
├── profiles/                         # 7 Hermes profiles
├── skills/                           # 5 skills for the running Hermes
├── templates/                        # 6 artifact templates
├── examples/hello-sparc/             # end-to-end example
├── docs/                             # INSTALL, ARCHITECTURE, HITL, ADDING-STAGES, TROUBLESHOOTING, FAQ
├── tests/                            # 111 tests, all passing
├── .github/                          # issue + PR templates
├── LICENSE                           # MIT
├── CONTRIBUTING.md
├── CHANGELOG.md
└── README.md                         # you are here
```

**111 tests across 5 suites, all passing:**

```
test_adapters.sh                 20 pass  ·  0 fail
test_e2e.sh                      14 pass  ·  0 fail
test_kanban.sh                   14 pass  ·  0 fail
test_setup.sh                    54 pass  ·  0 fail
test_validators.sh                9 pass  ·  0 fail
```

---

## 📚 Documentation

- **[INSTALL.md](docs/INSTALL.md)** — Detailed install walkthrough, troubleshooting, idempotency
- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** — How the pieces fit, with diagrams
- **[HITL.md](docs/HITL.md)** — Human-in-the-loop adapters, how to author one
- **[ADDING-STAGES.md](docs/ADDING-STAGES.md)** — How to add/remove/reorder stages
- **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** — Common failure modes and fixes
- **[FAQ.md](docs/FAQ.md)** — Frequently asked questions

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Bug reports, new HITL adapters, new stage definitions, and docs improvements all welcome. The maintainers review PRs on a regular cadence (not a fixed SLA).

---

## 🗺️ Roadmap

- **[ROADMAP.md](ROADMAP.md)** is the canonical roadmap — read it for the full reasoning, gap analysis, and version-by-version plan. The short version:
- **v0.1.0** (this release) — core package, 6 stages, 5 skills, 5 HITL adapters
- **v0.2.0** — "make it work reliably": event-based poller, kanban CLI compat shim, stale-task reaper, real reviewer checklist skill, per-stage model routing, integration test suite, CI, prerequisites check
- **v0.3.0** — "make it pleasant": structured HITL gate types (confidence / sampling / exception), `sparc status` observability, artifact reconciler, log rotation, JSON schema
- **v0.4.0** — "make it adoptable": `sparc new` interactive template, hosted demo, local web dashboard, chat-gateway notify channels, video walkthrough
- **v1.0.0** — "make it a product": stable CLI surface with semver, Hermes marketplace publication, optional multi-user mode, optional external PM tool mirror

Want to suggest something? Open an issue with the [`feature_request` template](https://github.com/jb-bz/sparqr/issues/new?template=feature_request.md) — features get triaged against the roadmap before being added.

---

## 🌟 Acknowledgments

- [Hermes Agent](https://hermes-agent.nousresearch.com/) — the agent runtime
- [ruvnet](https://github.com/ruvnet) — the original [SPARC](https://github.com/ruvnet/sparc) methodology
- [Nesquena](https://github.com/nesquena) — [`hermes-webui`](https://github.com/nesquena/hermes-webui) and its built-in kanban panel
- The [`hermes-workspace`](https://github.com/outsourc-e/hermes-workspace) maintainers — Swarm Mode Kanban TaskBoard
- The MAST authors (arXiv 2503.13657) — for quantifying *why* stage gates matter

---

<div align="center">

**[⬆ back to top](#-sparqr)** · made with ⚡️ in plain bash + sqlite + jq

</div>
